class TimesheetController < ApplicationController
  layout 'base'

  if Rails::VERSION::MAJOR >= 4
    before_action :get_list_size
    before_action :get_precision
    before_action :get_activities
  else
    before_filter :get_list_size
    before_filter :get_precision
    before_filter :get_activities
  end

  helper :sort
  include SortHelper
  helper :issues
  include ApplicationHelper
  helper :timelog
  SessionKey = 'timesheet_filter'

  def index
    return unless User.current.allowed_to? :view_time_entries, nil, :global => true
    load_filters_from_session
    unless @timesheet
      @timesheet ||= Timesheet.new
    end
    @timesheet.allowed_projects = allowed_projects
    if @timesheet.allowed_projects.empty?
      render :action => 'no_projects'
    end
  end

  def report
    return unless User.current.allowed_to? :view_time_entries, nil, :global => true
    if params && params[:timesheet]
      @timesheet = Timesheet.new(params[:timesheet])
    else
      redirect_to :action => 'index'
      return
    end

    @timesheet.allowed_projects = allowed_projects

    if @timesheet.allowed_projects.empty?
      render :action => 'no_projects'
    end

    if !params[:timesheet][:projects].blank?
      @timesheet.projects = @timesheet.allowed_projects.find_all { |project|
        params[:timesheet][:projects].include?(project.id.to_s)
      }
    else
      @timesheet.projects = @timesheet.allowed_projects
    end

    call_hook(:plugin_timesheet_controller_report_pre_fetch_time_entries, { :timesheet => @timesheet, :params => params })
    save_filters_to_session(@timesheet)
    @timesheet.fetch_time_entries

    # collect spent time per project
    @total = {}
    unless @timesheet.sort == :issue
      @timesheet.time_entries.each do |project, logs|
        @total[project] = []
        if logs[:logs]
          logs[:logs].each do |log|
            @total[project].push log.hours
          end
        end
      end
    else
      @timesheet.time_entries.each do |project, project_data|
        @total[project] = []
        if project_data[:issues]
          project_data[:issues].each do |issue, issue_data|
            @total[project].push issue_data.collect(&:hours).sum
          end
        end
      end
    end

    # sum hours per project
    @total.each do |project, hours|
      sum = hours.sum
      @total[project] = (sum.round - sum).abs < 0.05 ? sum.round : sum
    end

    @grand_total = @total.collect{|k,v| v}.sum

    respond_to do |format|
      format.html { render :action => 'details', :layout => false if request.xhr? }
      format.csv  { send_data @timesheet.to_csv, :filename => 'timesheet.csv', :type => "text/csv" }
      format.iif  {
        render(
          :iif => render_to_string(:locals => {
            :total        => @total,
            :grand_total  => @grand_total,
            :timesheet    => @timesheet,
            :date_from    => @timesheet.date_from.to_date,
            :date_to      => @timesheet.date_to.to_date
          }),
          :filename => "timesheet-#{@timesheet.projects.collect{|p| p.id.to_s.rjust(3, '0')}.join('')}"
        )
      }
    end
  end

  def context_menu
    @time_entries = TimeEntry.where(['id IN (?)', params[:ids]])
    render :layout => false
  end

  def reset
    clear_filters_from_session
    redirect_to :action => 'index'
  end

  private

  def get_list_size
    @list_size = Setting.plugin_redmine_timesheet['list_size'].to_i
  end

  def get_precision
    precision = Setting.plugin_redmine_timesheet['precision']

    if precision.blank?
      # Set precision to a high number
      @precision = 10
    else
      @precision = precision.to_i
    end
  end

  def get_activities
    @activities = TimeEntryActivity.where('parent_id IS NULL')
  end

  def allowed_projects
    # allowed_to? works with the default project-role-permission relationship.
    # if a user has no active role (for example if all projects are archived) then them has not the permission
    if User.current.admin? or User.current.allowed_to?(:see_all_timesheets, nil, {:global => true})
      Project.order('name ASC')
    else
      Project.where(Project.visible_condition(User.current)).order('name ASC')
    end
  end

  def clear_filters_from_session
    session[SessionKey] = nil
  end

  def load_filters_from_session
    if session[SessionKey]
      @timesheet = Timesheet.new(session[SessionKey])
      @timesheet.period_type = Timesheet::ValidPeriodType[:default]
    end

    if session[SessionKey] && session[SessionKey]['projects']
      @timesheet.projects = allowed_projects.find_all { |project|
        session[SessionKey]['projects'].include?(project.id.to_s)
      }
    end
  end

  def deep_clean(object)
    case object
    when Hash
      object.transform_values { |v| deep_clean(v) }
    when Array
      object.map { |v| deep_clean(v) }
    when String, Integer, Float, NilClass, TrueClass, FalseClass, Symbol
      object
    else
      object.to_s # Convert unsupported objects to strings
    end
  end

  def save_filters_to_session(timesheet)
    if params[:timesheet]
      # Check that the params will fit in the session before saving
      # prevents an ActionController::Session::CookieStore::CookieOverflow
      cleaned_timesheet = deep_clean(params[:timesheet].permit!.to_h)
      encoded = Base64.encode64(Marshal.dump(cleaned_timesheet))
      if encoded.size < 2.kilobytes
        session[SessionKey] = cleaned_timesheet
      end
    end

    if timesheet
      session[SessionKey] ||= {}
      session[SessionKey]['date_from'] = timesheet.date_from
      session[SessionKey]['date_to'] = timesheet.date_to
    end
  end

end
