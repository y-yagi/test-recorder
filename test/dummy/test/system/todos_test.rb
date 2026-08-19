require "application_system_test_case"

class TodosTest < ApplicationSystemTestCase
  setup do
    @todo = todos(:one)
  end

  test "visiting the index" do
    visit todos_url
    assert_selector "h1", text: "Todos"
  end

  test "creating a Todo" do
    visit todos_url
    click_on "New todo"

    fill_in "Title", with: @todo.title
    click_on "Create Todo"

    assert_text "Todo was successfully created"
    click_on "Back"
  end

  test "updating a Todo" do
    visit todos_url
    click_on "Show this todo", match: :first
    click_on "Edit this todo"

    fill_in "Title", with: @todo.title
    click_on "Update Todo"

    assert_text "Todo was updated"
    click_on "Back"
  end

  test "updating a Todo from /todos/:id/edit" do
    visit todos_url
    click_on "Show this todo", match: :first
    click_on "Edit this todo"

    fill_in "Title", with: @todo.title
    click_on "Update Todo"

    assert_text "Todo was updated"
    click_on "Back"
  end

  test "destroying a Todo" do
    visit todos_url
    click_on "Show this todo", match: :first
    click_on "Destroy this todo"

    assert_text "Todo was successfully destroyed"
  end

  test "skipping after the page is loaded" do
    visit todos_url
    assert_selector "h1", text: "Todos"

    skip "the rest of this test is not ready yet"
  end

  test "failing before the page is loaded" do
    flunk "fails before anything is drawn, so there is nothing to record"
  end

  test "without test recorder", test_recorder: false do
    visit todos_url
    click_on "Show this todo", match: :first
    click_on "Edit this todo"
    fill_in "Title", with: @todo.title
    click_on "Update Todo"

    assert_text "Todo was updated"
    click_on "Back"
  end
end
