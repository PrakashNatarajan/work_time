class TimeEntry < ActiveRecord::Base


  scope :by_user, lambda{|user| where(:user_id => user)}
  scope :by_spent, lambda{|day| where(:spent_on => day)}
  scope :by_issue, lambda{|issue| where(:issue_id => issue)}

end
