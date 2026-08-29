describe 'changes', type: :feature, js: true do

  let(:version) { Unpoly::Guide.current.stable_version }

  it 'shows the changelog of a release' do
    visit "/changes/#{version}"

    expect(page).to have_css('h1', text: "Version #{version}")
    expect(page).to have_css('.prose')
  end

  it 'links from the changes index to the release of the current version' do
    visit '/changes'

    expect(page).to have_css("a[href='/changes/#{version}']")
  end

end
