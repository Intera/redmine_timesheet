# redmine timesheet plugin
list and filter all timelog entries in redmine.

compatible with redmine version 4 and 3.

![form-screenshot](other/screenshots/form.png?raw=true)
![result-screenshot](other/screenshots/result.png?raw=true)

# features
* filtering and sum of timelogs by date range, projects, activities and users
* grouping of timelogs by project, issue and user
* access control based on the user's projects and roles
* permalinks to reports
* special print style with total hours per day summaries
* csv exports
* version field in the report table
* cleaned up form layout
* headers of multiselects select all elements. they also deselect all elements if all elements are already selected
* a new permission that allows to see all timelogs of all users (use case: secretary can print timesheets for the month for all users)
* plugin hook support for changing the behavior of the plugin
* user configurable precision for hours

# installation
1. in your redmine `plugins` directory, run the command: `git clone https://github.com/Intera/redmine_timesheet redmine_timesheet`
2. restart the web server
3. login and click the timesheet link in the top left menu

## upgrade
1. open a shell to your redmine `plugins/redmine_timesheet` directory
2. update your git copy with `git pull`
3. restart redmine

# license
gnu gpl v2.

this plugin is a fork of the (original version)[https://github.com/edavis10/redmine-timesheet-plugin] by eric davis and has the same license.

# see also
(redmine time logging app)[https://github.com/Intera/redmine_time_logging_app] - let users log time for any project in one place
