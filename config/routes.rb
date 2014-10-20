  get '/user-calendar', :to => 'w_calendars#show_calendar', :as => 'user_calendar'

  resources :work_timelog, :controller => 'work_timelog', :except => [:show, :destroy] do
    collection do
      post 'bulk_create', :as => :bulk_create
      get 'bulk_edit', :as => :bulk_edit
      post 'bulk_update', :as => :bulk_update
    end
  end


  match '/bulk_time_entries', :to => 'work_timelog#bulk_new', :via => :get, :as => :bulk_time_entries
  match '/bulk_time_entries_weekly', :to => 'work_timelog#bulk_new_weekly', :via => :get, :as => :bulk_time_entries_weekly
