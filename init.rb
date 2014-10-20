Redmine::Plugin.register :work_time do
  name 'Work Time plugin'
  author 'Prakash Natarajan'
  description 'This is a plugin for bulk time enteries in Redmine'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'
end

=begin
ApplicationHelper.module_eval do
  def favicon_path
    icon = (current_theme && current_theme.favicon?) ? current_theme.favicon_path : '/old_favicon.ico'
    image_path(icon)
  end
end
=end

Redmine::AccessControl.map do |map|
  map.project_module :time_tracking do |map|
      map.permission :edit_bulk_time_entries, {:work_timelog => [:bulk_new, :bulk_new_weekly, :bulk_create, :bulk_edit, :bulk_update, :destroy]}, :require => :member
      map.permission :edit_own_bulk_time_entries, {:work_timelog => [:bulk_new, :bulk_new_weekly, :bulk_create, :bulk_edit, :bulk_update, :destroy]}, :require => :loggedin
  end
  map.project_module :calendar do |map|
    map.permission :timelog_calendar, {:w_calendars => [:show_calendar]}, :read => true
  end
end

Redmine::MenuManager.map :top_menu do |menu|
  menu.push :time_entries, { :controller => 'timelog', :action => 'index' }, :if => Proc.new { User.current.logged? }
  menu.push :log_calendar, { :controller => 'w_calendars', :action => 'show_calendar' }, :if => Proc.new { User.current.logged? }
end

Redmine::Helpers::Calendar.class_eval do
  # Sets calendar events
  def events=(events)
    @events = [events].flatten
    if @events[0].is_a?(TimeEntry)
      @ending_events_by_days = @events.group_by {|event| event.spent_on}
      @starting_events_by_days = @events.group_by {|event| event.spent_on}
    else
      @ending_events_by_days = @events.group_by {|event| event.due_date}
      @starting_events_by_days = @events.group_by {|event| event.start_date}
    end
  end
end

TimeEntry.class_eval do
  scope :by_user, lambda{|user| where(:user_id => user)}
  scope :by_spent, lambda{|day| where(:spent_on => day)}
  scope :by_issue, lambda{|issue| where(:issue_id => issue)}
end

User.class_eval do
  def allowed_to?(action, context, options={}, &block)
    #context = context.to_a.uniq if context and context.class.name == "ActiveRecord::Relation"
    if context && context.is_a?(Project)
      return false unless context.allows_to?(action)
      # Admin users are authorized for anything else
      return true if admin?

      roles = roles_for_project(context)
      return false unless roles
      roles.any? {|role|
        (context.is_public? || role.member?) &&
            role.allowed_to?(action) &&
            (block_given? ? yield(role, self) : true)
      }
    elsif context && (context.is_a?(Array) || context.is_a?(ActiveRecord::Relation))
      if context.empty?
        false
      else
        # Authorize if user is authorized on every element of the array
        context.map {|project| allowed_to?(action, project, options, &block)}.reduce(:&)
      end
    elsif options[:global]
      # Admin users are always authorized
      return true if admin?

      # authorize if user has at least one role that has this permission
      roles = memberships.collect {|m| m.roles}.flatten.uniq
      roles << (self.logged? ? Role.non_member : Role.anonymous)
      roles.any? {|role|
        role.allowed_to?(action) &&
            (block_given? ? yield(role, self) : true)
      }
    else
      false
    end
  end
end

ApplicationController.class_eval do

  private

  def find_optional_project
    if params[:controller] == "w_calendars" && params[:action] == "show_calendar"
      @project = User.current.projects.first
    else
      @project = Project.find(params[:project_id]) unless params[:project_id].blank?
    end
    allowed = User.current.allowed_to?({:controller => params[:controller], :action => params[:action]}, @project, :global => true)
    allowed ? true : deny_access
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end

=begin
Redmine::Info.instance_eval do
    def app_name
      'Netserv Redmine'
    end
    def url
      'http://www.smnetserv.com'
    end
end
=end