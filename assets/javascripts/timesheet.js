function report_add_calendar_weeks() {
	var first = $("tr.week-number").first()
	first_text = first.find("td:nth-child(9)").text()
	first.remove()
	first = $("<div>", {"class": "week-number"}).append(first_text)
	$("#time_entries > h3").after(first)
}

$(function() {
  $('#select_timesheet_period_type_1').focus(function() {
    $('#timesheet_period_type_1').attr('checked','checked')
  })

  $('#select_timesheet_period_type_2').click(function() {
    $('#timesheet_period_type_2').attr('checked','checked')
  })

	$("label.select-all").click(function () {
		var select = $(this).siblings("select")
		var options = select.children()
		var selected = options.length != select.find(":selected").length
		options.each(function (index, a) { a.selected = selected });
	})

	report_add_calendar_weeks()
})
