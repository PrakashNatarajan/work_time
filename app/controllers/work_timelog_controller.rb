class WorkTimelogController < ApplicationController
  menu_item :issues

  before_filter :find_time_entries, :only => [:bulk_edit, :bulk_update, :destroy]
  before_filter :find_user_projects, :only => [:bulk_new, :bulk_new_weekly, :bulk_create]
  before_filter :authorize

  accept_api_auth :destroy

  rescue_from Query::StatementInvalid, :with => :query_statement_invalid


  helper :sort
  include SortHelper
  helper :issues
  include TimelogHelper
  include WorkTimelogHelper
  helper :custom_fields
  include CustomFieldsHelper
  helper :queries
  include QueriesHelper

  def bulk_new
    @date = params[:date] || ""
    @available_activities = TimeEntryActivity.shared.active
    @custom_fields = TimeEntry.first.available_custom_fields
  end

  def bulk_new_weekly
    @available_activities = TimeEntryActivity.shared.active
    @custom_fields = TimeEntry.first.available_custom_fields
  end

  def bulk_create
    if (not params[:time_entries_weekly].blank? and params[:time_entries_weekly]=="true")
      attributes = params_for_bulk_time_entry_attributes_weekly(params)
      attributes_arr = attributes
     else
      attributes = parse_params_for_bulk_time_entry_attributes(params)
      attributes_arr = attributes.values
    end

    @time_entries = []
    attributes_arr.each do |timentrattr|
      if not timentrattr.blank?
          time_entry = TimeEntry.new(:project => find_optional_project(timentrattr), :issue_id => timentrattr[:issue_id], :user => User.current, :spent_on => User.current.today, :hours => timentrattr[:hours])
          time_entry.safe_attributes = timentrattr
          call_hook(:controller_time_entries_bulk_create_before_save, { :params => params, :time_entry => time_entry })
          @time_entries << time_entry
      end
    end
    if @time_entries.all?(&:valid?)
       @time_entries.each(&:save!)
       flash[:notice] = l(:notice_successful_create)
       redirect_to("/time_entries")
    else
       respond_to do |format|
         @available_activities = TimeEntryActivity.shared.active
         @date = params[:date] || ""
           format.html do
             if (not params[:time_entries_weekly].blank? and params[:time_entries_weekly]=="true")
                render :action => 'bulk_new_weekly'
             else
                render :action => 'bulk_new'
             end
           end
         format.api  { render_validation_errors(@time_entries) }
       end
    end
  end

  def bulk_edit
    @available_activities = TimeEntryActivity.shared.active
    @custom_fields = TimeEntry.first.available_custom_fields
  end

  def bulk_update
    attributes = parse_params_for_bulk_time_entry_attributes(params)

    unsaved_time_entry_ids = []
    @time_entries.each do |time_entry|
      time_entry.reload
      time_entry_attr = attributes["#{time_entry.id}"] || ""
      if !time_entry_attr.blank?
        if (not time_entry_attr["_delete"].blank? and time_entry_attr["_delete"] == "true")
          time_entry.destroy
        else
          time_entry.safe_attributes = time_entry_attr
          time_entry.spent_on = time_entry_attr["spent_on"]
          time_entry.activity_id = time_entry_attr["activity_id"]
        end
        call_hook(:controller_time_entries_bulk_edit_before_save, { :params => params, :time_entry => time_entry })
        unless time_entry.save
          logger.info "time entry could not be updated: #{time_entry.errors.full_messages}" if logger && logger.info
          # Keep unsaved time_entry ids to display them in flash error
          unsaved_time_entry_ids << time_entry.id
        end
      end
    end
    set_flash_from_bulk_time_entry_save(@time_entries, unsaved_time_entry_ids)
    redirect_back_or_default project_time_entries_path(@projects.first)
  end

  def destroy
    @time_entry = TimeEntry.find(params[:id])
    @time_entry.destroy
    respond_to do |format|
      format.html {
        if @time_entry.destroyed?
          flash[:notice] = l(:notice_successful_delete)
        else
          flash[:error] = l(:notice_unable_delete_time_entry)
        end
        redirect_back_or_default project_time_entries_path(@projects.first)
      }
      format.api  {
        if destroyed
          render_api_ok
        else
          render_validation_errors(@time_entries)
        end
      }
    end
  end

private

  def find_time_entries
    if (not params[:id].blank? and not params[:ids].blank?)
      @time_entries = TimeEntry.where(:id => params[:id] || params[:ids]).all
    else
      @time_entries = TimeEntry.where(:user_id => User.current).all
    end
    @user = User.current
    raise ActiveRecord::RecordNotFound if @time_entries.empty?
    @projects = @time_entries.collect(&:project).compact.uniq.sort
    @project = @projects.first if @projects.uniq.size == 1
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_optional_project(time_entry=nil)
    params = time_entry.blank? ? params : time_entry
    if !params.blank? && !params[:issue_id].blank?
      @issue = Issue.find(params[:issue_id])
      @project = @issue.project
    elsif !params.blank? && !params[:project_id].blank?
      @project = Project.find(params[:project_id])
    end
  end

  def find_user_projects
    @user = User.current
    @projects = @user.projects.joins(:issues)
    @week_days, @previous, @next_day, @now_today = current_week(params[:date])
    from = @week_days.collect{|date| date}.first
    to = @week_days.collect{|date| date}.last
    @time_entries = TimeEntry.by_user(@user).spent_between(from, to)
  end

  def set_flash_from_bulk_time_entry_save(time_entries, unsaved_time_entry_ids)
    if unsaved_time_entry_ids.empty?
      flash[:notice] = l(:notice_successful_update) unless time_entries.empty?
    else
      flash[:error] = l(:notice_failed_to_save_time_entries,
                        :count => unsaved_time_entry_ids.size,
                        :total => time_entries.size,
                        :ids => '#' + unsaved_time_entry_ids.join(', #'))
    end
  end

  def parse_params_for_bulk_time_entry_attributes(params)
    attributes = (params[:time_entry] || {}).reject {|k,v| v.blank?}
    attributes.each_pair do |key, val_hash|
      if val_hash.fetch("hours").blank?
        attributes["#{key}"] = ""
      end
    end
    attributes.keys.each {|k| attributes[k] = '' if attributes[k] == 'none'}
    attributes[:custom_field_values].reject! {|k,v| v.blank?} if attributes[:custom_field_values]
    attributes
  end

  def params_for_bulk_time_entry_attributes_weekly(params)
    attributes = (params[:time_entry].values || []).each{|arr| (arr || {}).reject {|k,v| v.blank?}}
    arr_attr = []
    attributes.each do |arr_hash|
      arr_hash.each_pair do |key, val_hash|
        if !val_hash.fetch("hours").blank?
          arr_attr <<  val_hash
        end
      end
    end
    arr_attr.each_with_index {|attr, index| attr.keys.each {|k| arr_attr[index][k] = '' if attr[k] == 'none'}}
    arr_attr
  end

end
