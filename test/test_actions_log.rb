require_relative 'prerequisites'

class ActionsLogTest < Test::Unit::TestCase

  def setup
    @valid
  end

  def test_create_log_template
    # current_user_id = current_user_id
    # log = ActionsLog.new.set(msg: "#{t('production.load.assigned', label: i.id, p_name: p.p_name, locale: :es)}", u_id: current_user_id, l_id: User.new.current_location[:name], lvl:  ActionsLog::INFO, i_id: i.id, p_id: p.p_id)
  end

  def test_should_validate_msg_and_user
    log = ActionsLog.new.set(msg: "Dummy", u_id: 1)
    assert( log.valid? )
    log.u_id = nil
    assert_false( log.valid?, "No user given validation" )
    log.msg = nil
    log.u_id = 1
    assert_false( log.valid?, "No message given validation" )
  end

  def test_should_reject_invalid_id
    log = ActionsLog.new.set(msg: "Test log", u_id: 1)
    log.b_id = "sdfsd"
    assert_false( log.valid?, "Accepts an invalid bulk_id" )
  end


end
