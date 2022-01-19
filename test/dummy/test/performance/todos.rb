require "application_system_test_case"

class TodosTest < ApplicationSystemTestCase
  setup do
    @todo = todos(:one)
  end

  test "scaffold todo" do
    5.times do
      visit todos_url
      assert_selector "h1", text: "Todos"

      click_on "New Todo"

      fill_in "Title", with: @todo.title
      click_on "Create Todo"

      assert_text "Todo was successfully created"
      click_on "Back"

      click_on "Edit", match: :first

      fill_in "Title", with: @todo.title
      click_on "Update Todo"

      assert_text "Todo was successfully updated."
      click_on "Back"

      page.accept_confirm do
        click_on "Destroy", match: :first
      end

      assert_text "Todo was successfully destroyed"
    end
  end
end
