require 'redmine'

if Rails::VERSION::MAJOR < 3
  require 'dispatcher'
  object_to_prepare = Dispatcher
else
  object_to_prepare = Rails.configuration
  # if redmine plugins were railties:
  # object_to_prepare = config
end

object_to_prepare.to_prepare do
  require_dependency 'project'
  require_dependency 'principal'
  require_dependency 'user'
  require_dependency 'time_entry'
  Project.send(:include, RedmineTimesheetPlugin::Patches::ProjectPatch)
  User.send(:include, RedmineTimesheetPlugin::Patches::UserPatch)
  TimeEntry.send(:include, RedmineTimesheetPlugin::Patches::TimeEntryPatch)
  # Needed for the compatibility check
  begin
    require_dependency 'time_entry_activity'
  rescue LoadError
    # TimeEntryActivity is not available
  end
end

unless Redmine::Plugin.registered_plugins.keys.include?(:redmine_timesheet_plugin)
  Redmine::Plugin.register :redmine_timesheet_plugin do
    name 'Redmine Timesheet Plugin'
    author 'Arkhitech'
    description 'This is a Timesheet plugin for Redmine to show timelogs for all projects'
    url 'http://github.com/arkhitech/redmine_timesheet_plugin'
    author_url 'https://github.com/arkhitech'
    version '0.7.0'
    requires_redmine :version_or_higher => '2.0.0'
    settings(:default => {
               'list_size' => '5',
               'precision' => '2',
               'project_status' => 'active',
               'user_status' => 'active'
             }, :partial => 'settings/timesheet_settings')
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
