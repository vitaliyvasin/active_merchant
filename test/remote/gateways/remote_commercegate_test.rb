require 'test_helper'

class RemoteCommercegateTest < Test::Unit::TestCase

  # Contact Support at it_support@commercegate.com

  def setup
    @gateway = CommercegateGateway.new(
      :login => fixtures(:commercegate).fetch(:login),  # Contact support for username / password
      :password => fixtures(:commercegate).fetch(:password)
    )

    @amount = 1000 # Must match the offerID

    @options = {
      :ip => '192.168.7.175', # conditional, required for authorize and purchase, #Any valid IP will work
      :email => 'john_doe01@yahoo.com', # required
      :merchant => '', # conditional, required only when you have multiple merchant accounts
      :currency => 'EUR', # required, Must match the offerID
      :address => address,
      # conditional, required for authorize and purchase
      :site_id => fixtures(:commercegate).fetch(:site_id), # Contact support for test site ID
      :offer_id => fixtures(:commercegate).fetch(:offer_id) # Contact support for test OFFER ID
    }

    @credit_card = get_credit_card(false)
    @expired_credit_card = get_credit_card(true)
  end

  def test_successful_authorize
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response, response_message(response)
    assert_equal response.params['action'], 'AUTH'
    assert_equal 'U', response.avs_result["code"]
    assert_equal 'M', response.cvv_result["code"]
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response, response_message(response)
    assert_equal response.params['action'], 'SALE'
    assert_equal 'U', response.avs_result["code"]
    assert_equal 'M', response.cvv_result["code"]
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @expired_credit_card, @options)
    assert_failure response
    assert_equal 'Card expired', response.message
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Success', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization, @options)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '123', @options)
    assert_failure response
    assert_equal 'Previous transaction not found', response.message
  end

  def test_invalid_login
    gateway = CommercegateGateway.new(
                :login => '',
                :password => ''
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Unauthorized Use: You do not have privilege to use this action.', response.message
  end

  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response, response_message(response)
    assert trans_id = response.params['transID']

    assert response = @gateway.refund(@amount, trans_id, @options)
    assert_success response, response_message(response)
    assert_equal response.params['action'], 'REFUND'
  end

  def test_successful_void
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response, response_message(response)
    assert trans_id = response.params['transID']
    assert response = @gateway.void(trans_id)
    assert_success response, response_message(response)
    assert_equal response.params['action'], 'VOID_AUTH'
  end

  private

  def response_message(response = {})
    "Return code = " + response.params['returnCode'] + " " + response.params['returnText']
  end

  def get_credit_card(is_expired)
    credit_card = ActiveMerchant::Billing::CreditCard.new(
      :first_name         => 'John', #Any name will work
      :last_name          => 'Doe',
      :number             => fixtures(:commercegate).fetch(:card_number), # Contact support for test card number(s)
      :month              => '01', # Any future date will work
      :year               => is_expired == true ? Time.now.year - 1 : Time.now.year + 1,
      :verification_value => '123') # Any 3 digit code will work
  end

end
