require "redmine"

if Rails::VERSION::MAJOR < 3
  require "dispatcher"
  object_to_prepare = Dispatcher
else
  object_to_prepare = Rails.configuration
  # if redmine plugins were railties:
  # object_to_prepare = config
end

object_to_prepare.to_prepare do
  require_dependency "project"
  require_dependency "principal"
  require_dependency "user"
  require_dependency "time_entry"
  Project.send(:include, RedmineTimesheet::Patches::ProjectPatch)
  User.send(:include, RedmineTimesheet::Patches::UserPatch)
  TimeEntry.send(:include, RedmineTimesheet::Patches::TimeEntryPatch)
  begin
    require_dependency "time_entry_activity"
  rescue LoadError
    # TimeEntryActivity is not available
  end
end

unless Redmine::Plugin.registered_plugins.keys.include?(:redmine_timesheet)
  Redmine::Plugin.register :redmine_timesheet do
    author "Arkhitech"
    author_url "https://github.com/arkhitech"
    description "This is a Timesheet plugin for Redmine to show timelogs for all projects"
    name "Redmine Timesheet Plugin"
    requires_redmine :version_or_higher => "2.0.0"
    url "http://github.com/intera/redmine_timesheet"
    version "0.8.0"
    settings(:default => {
               "list_size" => "5",
               "precision" => "2",
               "project_status" => "active",
               "user_status" => "active"
             }, :partial => "settings/timesheet_settings")
    project_module :timesheet do
	    permission :see_all_timesheets, {}
    end
    menu(:top_menu,
         :timesheet,
         {:controller => :timesheet, :action => :index},
         :caption => :timesheet_title,
         :if => Proc.new {
           User.current.allowed_to?(:view_time_entries, nil, :global => true) or
             User.current.allowed_to?(:see_all_timesheets, nil, :global => true) or
             User.current.admin?
         })
  end
end
