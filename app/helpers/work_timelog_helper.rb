
module WorkTimelogHelper
  include ApplicationHelper

  def error_messages_for_timelog(*objects)
    html = ""
    objects = objects.map {|o| o.is_a?(String) ? instance_variable_get("@#{o}") : o}.compact
    errors = objects.flatten.map {|o| o.errors.full_messages}.flatten
    if errors.any?
      html << "<div id='errorExplanation'><ul>\n"
      errors.each do |error|
        html << "<li>#{h error}</li>\n"
      end
      html << "</ul></div>\n"
    end
    html.html_safe
  end

  def sum_hours(data)
    sum = 0
    [data].flatten.each do |row|
      sum += row['hours'].to_f
    end
    sum
  end

  def current_week(date=nil)
    middleday = date.nil? ? Date.today : Date.parse("#{date}")
    today = Date.today
    if today < middleday
      middleday = Date.today
    end
    start_day = middleday.at_beginning_of_week - 1.day
    end_day = middleday.at_end_of_week - 1.day
    week = (start_day..end_day).map
    previous = middleday - 7.days
    next_day = middleday + 7.days
    return week, previous, next_day, today
  end

  def next_week_day?(next_day = nil)
    next_week = if next_day.nil?
                  (@now_today >= @next_day) ? true : @now_today >= (@next_day - 7.days) #false
                else
                  @now_today >= next_day
                end
    next_week
  end

  def timelog_project_issue?(issue, day = nil)
      week_days = @week_days.each{|day| day.strftime("%Y-%m-%d")}
      available = if day.nil?
                    (week_days.include?(issue.created_on.strftime("%Y-%m-%d")) || week_days.last >= issue.created_on.strftime("%Y-%m-%d"))
                  else
                    issue.created_on.strftime("%Y-%m-%d") <= day.strftime("%Y-%m-%d")
                  end
      available
  end

end
