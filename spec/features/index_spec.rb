describe 'index', :type => :feature do
  before do
    visit '/'
  end

  it 'shows our claim' do
    expect(page).to have_css('h1', text: 'The unobtrusive JavaScript framework')
  end

  it 'refers to our forum' do
    expect(page).to have_content('GitHub Discussions')
  end
end
