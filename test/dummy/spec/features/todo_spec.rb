require 'rails_helper'

RSpec.feature "Todos", type: :feature do
  before do
    Capybara.default_driver = :selenium_chrome_headless
  end

  it "creating a Todo" do
    visit "/todos"
    click_on "New Todo"

    fill_in "Title", with: "Todo Title"
    click_on "Create Todo"

    expect(page).to have_text "Todo successfully created"
  end
end
