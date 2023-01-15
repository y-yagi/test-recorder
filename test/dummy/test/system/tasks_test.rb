require "application_system_test_case"

class TasksTest < ApplicationSystemTestCase
  setup do
    @task = tasks(:one)
  end

  test "visiting the index" do
    visit tasks_url
    assert_selector "h1", text: "Tasks"
  end

  test "should create task" do
    visit tasks_url
    click_on "New task"

    20.times do |i|
      fill_in "Body1", with: "body1 - #{i}"
      fill_in "Body2", with: "body2 - #{i}"
      fill_in "Body3", with: "body3 - #{i}"
      fill_in "Body4", with: "body4 - #{i}"
      fill_in "Body5", with: "body5 - #{i}"
    end

    click_on "Create Task"

    assert_text "Task was created"
    click_on "Back"
  end
end
