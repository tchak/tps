# frozen_string_literal: true

describe 'Accessing the website in different languages:' do
  # The test browser prefers french: the selector must show up anyway
  scenario 'I can change the language of the page' do
    visit new_user_session_path
    expect(page).to have_text("Connexion à #{APPLICATION_NAME}")

    find('.fr-translate__btn').click
    find('.fr-nav__link[lang="en"]').click

    # The page is now in English
    expect(page).to have_text('Sign in')
    # The page URL stayed the same
    expect(page).to have_current_path(new_user_session_path)
  end
end
