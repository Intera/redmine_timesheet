class Timesheet
  attr_accessor :date_from, :date_to, :projects, :activities, :users, :groups, :allowed_projects, :period, :period_type

  # Time entries on the Timesheet in the form of:
  #   project.name => {:logs => [time entries], :users => [users shown in logs] }
  #   project.name => {:logs => [time entries], :users => [users shown in logs] }
  # project.name could be the parent project name also
  attr_accessor :time_entries

  # Array of TimeEntry ids to fetch
  attr_accessor :potential_time_entry_ids
  attr_accessor :spent_on

  # Sort time entries by this field
  attr_accessor :sort
  ValidSortOptions = {
    :user => 'User',
    :project => 'Project',
    :issue => 'Issue',
    :group => 'Group',
    :date => 'Date'
  }

  ValidPeriodType = {
    :free_period => 0,
    :default => 1
  }

  def initialize(options = { })
    self.projects = []
    self.time_entries = options[:time_entries] || {}
    self.potential_time_entry_ids = options[:potential_time_entry_ids] || []
    self.allowed_projects = options[:allowed_projects] || []
    self.groups = []

    unless options[:activities].nil?
      self.activities = options[:activities].collect do |activity_id|
        # Include project-overridden activities
        activity = TimeEntryActivity.find(activity_id)
        project_activities = TimeEntryActivity.where(['parent_id in (?)', activity.id]) if activity.parent_id.nil?
        project_activities ||= []
        [activity.id.to_i] + project_activities.collect(&:id)
      end.flatten.uniq.compact
    else
      self.activities =  TimeEntryActivity.all.collect { |a| a.id.to_i }
    end

    unless options[:users].nil?
      self.users = options[:users].collect { |u| u.to_i }
    else
      self.users = Timesheet.viewable_users.collect {|user| user.id.to_i }
    end

    if User.current.allowed_to?(:see_all_timesheets, nil, {:global => true})
      unless options[:groups].nil?
        self.groups= options[:groups].collect { |g| g.to_i }
        groups = Group.where(:id => self.groups)
        groups.each do |group|
          self.users += group.user_ids
        end
        self.users.uniq!
      else
        self.groups= Group.all
      end
    end

    if !options[:sort].nil? && options[:sort].respond_to?(:to_sym) && ValidSortOptions.keys.include?(options[:sort].to_sym)
      self.sort = options[:sort].to_sym
    else
      self.sort = :users
    end

    self.date_from = options[:date_from] || Date.today.to_s
    self.date_to = options[:date_to] || Date.today.to_s
    self.spent_on=options[:spent_on]

    if options[:period_type] && ValidPeriodType.values.include?(options[:period_type].to_i)
      self.period_type = options[:period_type].to_i
    else
      self.period_type = ValidPeriodType[:free_period]
    end
    self.period = options[:period] || nil
  end

  # Gets all the time_entries for all the projects
  def fetch_time_entries
    self.time_entries = {}
    case self.sort
    when :project
      fetch_time_entries_by_project
    when :user
      fetch_time_entries_by_user
    when :issue
      fetch_time_entries_by_issue
    when :group
      fetch_time_entries_by_group
    when :date
      fetch_time_entries_by_date
    else
      fetch_time_entries_by_project
    end
  end

  def period=(period)
    return if self.period_type == Timesheet::ValidPeriodType[:free_period]
    # Stolen from the TimelogController
    case period.to_s
    when 'today'
      self.date_from = self.date_to = Date.today
    when 'yesterday'
      self.date_from = self.date_to = Date.today - 1
    when 'current_week' # Mon -> Sun
      self.date_from = Date.today - (Date.today.cwday - 1)%7
      self.date_to = self.date_from + 6
    when 'last_week'
      self.date_from = Date.today - 7 - (Date.today.cwday - 1)%7
      self.date_to = self.date_from + 6
    when '7_days'
      self.date_from = Date.today - 7
      self.date_to = Date.today
    when 'current_month'
      self.date_from = Date.civil(Date.today.year, Date.today.month, 1)
      self.date_to = (self.date_from >> 1) - 1
    when 'last_month'
      self.date_from = Date.civil(Date.today.year, Date.today.month, 1) << 1
      self.date_to = (self.date_from >> 1) - 1
    when '30_days'
      self.date_from = Date.today - 30
      self.date_to = Date.today
    when 'current_year'
      self.date_from = Date.civil(Date.today.year, 1, 1)
      self.date_to = Date.civil(Date.today.year, 12, 31)
    when 'all'
      self.date_from = self.date_to = nil
    end
    self
  end

  def to_param
    {
      :projects => projects.collect(&:id),
      :date_from => date_from,
      :date_to => date_to,
      :activities => activities,
      :users => users,
      :sort => sort
    }
  end

  def to_csv
    out = "";
    CSV.generate(out, :encoding => 'utf-8', :force_quotes => true) do |csv|
      csv << csv_header

      # Write the CSV based on the group/sort
      case sort
      when :user, :project
        time_entries.sort.each do |entryname, entry|
          entry[:logs].each do |e|
            csv << time_entry_to_csv(e)
          end
        end
      when :issue
        time_entries.sort.each do |project, entries|
          entries[:issues].sort {|a,b| a[0].id <=> b[0].id}.each do |issue, time_entries|
            time_entries.each do |e|
              csv << time_entry_to_csv(e)
            end
          end
        end
      end
    end
    out
  end

  def self.viewable_users
    is_plugin_present = Setting.plugin_redmine_timesheet.present? and (Setting.plugin_redmine_timesheet['user_status'] == 'all')
    if User.current.allowed_to?(:see_all_timesheets, nil, :global => true)
      user_scope = is_plugin_present ? User.all : User.active
    else
      user_scope = [User.current]
    end
    user_scope.select {|user| user.allowed_to?(:log_time, nil, :global => true) }
  end

  protected

  def csv_header
    csv_data = [
      '#',
      l(:label_date),
      l(:label_member),
      l(:label_activity),
      l(:label_project),
      l(:label_version),
      l(:label_issue),
      "#{l(:label_issue)} #{l(:field_subject)}",
      l(:field_comments),
      l(:field_hours)
    ]
    Redmine::Hook.call_hook(:plugin_timesheet_model_timesheet_csv_header, { :timesheet => self, :csv_data => csv_data})
    csv_data
  end

  def time_entry_to_csv(time_entry)
    csv_data = [
      time_entry.id,
      time_entry.spent_on,
      time_entry.user.name,
      time_entry.activity.name,
      time_entry.project.name,
      (time_entry.issue.fixed_version if time_entry.issue),
      ("#{time_entry.issue.tracker.name} ##{time_entry.issue.id}" if time_entry.issue),
      (time_entry.issue.subject if time_entry.issue),
      time_entry.comments,
      time_entry.hours
    ]
    Redmine::Hook.call_hook(:plugin_timesheet_model_timesheet_time_entry_to_csv, { :timesheet => self, :time_entry => time_entry, :csv_data => csv_data})
    csv_data
  end

  # Array of users to find
  # String of extra conditions to add onto the query (and)
  def conditions(users, extra_conditions=nil)
    if self.potential_time_entry_ids.empty?
      if self.date_from.present? && self.date_to.present?
        projects = self.projects.map{|e| e[:id]}
        conditions = ["spent_on >= (:from) and spent_on <= (:to) and #{TimeEntry.table_name}.project_id in (:projects) and user_id in (:users) and activity_id in (:activities)",
          {
            :from => self.date_from,
            :to => self.date_to,
            :projects => projects,
            :activities => self.activities,
            :groups => self.groups,
            :users => users
          }]
      else # All time
        projects = self.projects.map{|e| e[:id]}
        conditions = ["#{TimeEntry.table_name}.project_id in (:projects) and user_id in (:users) and activity_id in (:activities)",
          {
            :projects => projects,
            :activities => self.activities,
            :groups => self.groups,
            :users => users
          }]
      end
    else
      conditions = ["user_id in (:users) and #{TimeEntry.table_name}.id in (:potential_time_entries)",
        {
          :users => users,
          :potential_time_entries => self.potential_time_entry_ids
        }]
    end

    if extra_conditions
      conditions[0] = conditions.first + ' and ' + extra_conditions
    end

    Redmine::Hook.call_hook(:plugin_timesheet_model_timesheet_conditions, { :timesheet => self, :conditions => conditions})
    conditions
  end

  def includes
    includes = [:activity, :user, :project, {:issue => [:tracker, :assigned_to, :priority]}]
    Redmine::Hook.call_hook(:plugin_timesheet_model_timesheet_includes, { :timesheet => self, :includes => includes})
    includes
  end

  private

  def time_entries_for_all_users(project)
    project.time_entries.includes(self.includes).
      where(self.conditions(self.users)).
      order('spent_on ASC')
  end

  def time_entries_for_all_users_in_group(group)
    TimeEntry.includes(self.includes).
      where(self.conditions(group.user_ids)).
      order('spent_on ASC')
  end

  def time_entries_for_current_user(project)
    project.time_entries.
      includes(self.includes + [:activity, :user, {:issue => [:tracker, :assigned_to, :priority]}]).
      where(self.conditions(User.current.id)).
      order('spent_on ASC')
  end

  def issue_time_entries_for_all_users(issue)
    issue.time_entries.includes(self.includes + [:activity, :user]).
      where(self.conditions(self.users)).
      order('spent_on ASC')
  end

  def issue_time_entries_for_current_user(issue)
    issue.time_entries.includes(self.includes + [:activity, :user]).
      where(self.conditions(User.current.id)).
      order('spent_on ASC')
  end

  def time_entries_for_user(user, options={})
    extra_conditions = options.delete :conditions
    TimeEntry.includes(self.includes).
      where(self.conditions([user], extra_conditions)).
      order('spent_on ASC')
  end

  def fetch_time_entries_by_project
    puts self.projects
    self.projects.each do |project|
      logs = []
      users = []
      if current_user_allowed_to_see_all()
        logs = time_entries_for_all_users(project)
        users = logs.collect(&:user).uniq.sort
      elsif User.current.allowed_to? :view_time_entries, project
        logs = time_entries_for_current_user(project)
        users = logs.collect(&:user).uniq.sort
      end

      # Append the parent project name
      if project.parent.nil?
        unless logs.empty?
          self.time_entries[project.name] = { :logs => logs, :users => users }
        end
      else
        unless logs.empty?
          self.time_entries[project.parent.name + ' / ' + project.name] = { :logs => logs, :users => users }
        end
      end
    end
  end

  def fetch_time_entries_by_group
    groups = Group.where(:id => self.groups)
    groups.each do |group|
      logs = []
      users = []
      if User.current.admin?
        logs = time_entries_for_all_users_in_group(group)
        users = logs.collect(&:user).uniq.sort
      elsif User.current.groups == [group]
        #Users with the Role and correct permission can see all time entries
        logs = time_entries_for_all_users_in_group(group)
        users = logs.collect(&:user).uniq.sort
      end
      unless logs.empty?
        self.time_entries[group.name] = { :logs => logs, :users => users }
      end
    end
  end

  def current_user_allowed_to_see_all
    User.current.admin? or User.current.allowed_to?(:see_all_timesheets, nil, {:global => true})
  end

  def fetch_time_entries_by_user
    self.users.each do |user_id|
      logs = []
      if User.current.id == user_id or current_user_allowed_to_see_all()
        logs = time_entries_for_user user_id
      end
      unless logs.empty?
        user = User.find_by_id(user_id)
        self.time_entries[user.name] = { :logs => logs }  unless user.nil?
      end
    end
  end

  #   project => { :users => [users shown in logs],
  #                :issues =>
  #                  { issue => {:logs => [time entries],
  #                    issue => {:logs => [time entries],
  #                    issue => {:logs => [time entries]}
  #
  def fetch_time_entries_by_issue
    self.projects.each do |project|
      logs = []
      users = []
      project.issues.each do |issue|
        if current_user_allowed_to_see_all()
          # Administrators can see all time entries
          logs << issue_time_entries_for_all_users(issue)
        elsif User.current.allowed_to_on_single_potentially_archived_project?(:view_time_entries, project)
          # Users with permission to see their time entries
          logs << issue_time_entries_for_current_user(issue)
        end
      end

      logs.flatten! if logs.respond_to?(:flatten!)
      logs.uniq! if logs.respond_to?(:uniq!)

      unless logs.empty?
        users << logs.collect(&:user).uniq.sort
        issues = logs.collect(&:issue).uniq
        issue_logs = { }
        issues.each do |issue|
          issue_logs[issue] = logs.find_all {|time_log| time_log.issue == issue } # TimeEntry is for this issue
        end

        # TODO: TE without an issue

        self.time_entries[project] = { :issues => issue_logs, :users => users}
      end
    end
  end

  def fetch_time_entries_by_date
    logs = []
    # extra_conditions = 'GROUP_BY spent_on'
    logs=TimeEntry.includes(self.includes).where(self.conditions(self.users))

    unless logs.empty?
      logs.each do |log|
        date=log.spent_on
        logs_to_return=[]
        logs.each do |log2return|
          if log2return.spent_on==date
            logs_to_return << log2return
          end
        end
        self.time_entries[date] = { :logs => logs_to_return }
      end
    end
  end

  def l(*args)
    I18n.t(*args)
  end
end
