# The drawer slides in. WebDriver takes a click's coordinates from where an element is
# and dispatches the click a moment later, so a click during the slide lands where the
# element has moved away from: on the Learn row's toggle that is the "Learn" label,
# which follows the link and closes the drawer. A reader taps what is under their
# finger at that moment, so this is a test-only race; examples wait for the slide to
# end before they click inside the drawer.
module DrawerHelpers
  def wait_for_drawer_to_settle
    expect(page).to have_css('up-drawer .menu--nodes')
    deadline = Time.now + Capybara.default_max_wait_time
    until page.evaluate_script("(function(box) { return !!box && box.getAnimations().length === 0 })(document.querySelector('up-drawer-box'))")
      raise 'The drawer never stopped moving' if Time.now > deadline
      sleep 0.05
    end
  end
end

RSpec.configure do |config|
  config.include DrawerHelpers, type: :feature
end
