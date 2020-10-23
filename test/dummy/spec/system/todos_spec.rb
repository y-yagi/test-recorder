require 'rails_helper'

RSpec.describe "Todos", type: :system do
  before do
    driven_by(:selenium_chrome)
  end

  it "creating a Todo" do
    visit "/todos"
    click_on "New Todo"

    fill_in "Title", with: "Todo Title"
    click_on "Create Todo"

    expect(page).to have_text "Todo successfully created"
  end
end
