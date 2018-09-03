$(function() {
    $('#select_timesheet_period_type_2').click(function() {
        $('#timesheet_period_type_2').attr('checked','checked')
    })

    $('#select_timesheet_period_type_1').focus(function() {
        $('#timesheet_period_type_1').attr('checked','checked')
    })

    $("label.select-all").click(function () {
        var select = $(this).siblings("select")
        var options = select.children()
        var selected = options.length != select.find(":selected").length
        options.each(function (index, ele) { ele.selected = selected });
    })
})

function toggleTimeEntries(element) {
    $('.issue-time-entry-' + element).each(function() { $(this).toggle();} )
    $('.toggle-' + element).each(function() { $(this).toggle();} )
}

function toggleTimeEntriesIssue(id) {
    toggleTimeEntries(id);
}

function toggleTimeEntriesDate(entryname) {
    toggleTimeEntries(entryname);
}

/*
 * Checks all the Time Entries under issue_id
 */
function toggleTimeEntriesSelectionIssue(issue_id) {
    var issues = $('.issue-time-entry-' + issue_id);
    toggleTimeEntriesSelection(issues);
}

function toggleTimeEntriesSelectionProject(element){
    var table = $(element).parents('table.list.issues');
    toggleTimeEntriesSelection(table);
}

function toggleTimeEntriesSelection(element){
    var boxes = $(element).find('input[type=checkbox]');
    var all_checked = true;
    boxes.each(function(){ if (!$(this).prop('checked')) { all_checked = false; } });
    boxes.each(function(){
        if (all_checked) {
            $(this).removeAttr('checked');
            $(this).parents('tr').removeClass('context-menu-selection');
        } else if (!$(this).prop('checked')) {
            $(this).prop('checked', true);
            $(this).parents('tr').addClass('context-menu-selection');
        }
    });
}

