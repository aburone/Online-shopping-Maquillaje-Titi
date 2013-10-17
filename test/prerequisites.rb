require 'test/unit'
require 'rack/test'
require 'mocha/setup'
require 'sequel'
require 'pp'
require 'sinatra'
require 'sinatra/r18n'
require 'sinatra/config_file'
config_file '../../config.yml'
ENV["TZ"] = "GMT"

register Sinatra::R18n
R18n.default_places { './locales' }
R18n.set('es') # during tests it must be set explicitly
include R18n::Helpers

require 'encrypted_cookie'
require "rack/csrf"
use Rack::Session::EncryptedCookie, secret: settings.cookie_secret, expire_after: settings.session_length

# use Rack::Session::Cookie
# enable :sessions

require_relative '../helpers/init'
require_relative '../models/init'
# require_relative '../models/stdout_logger'

module Test::Unit::Assertions
  def assert_false(object, message="")
    assert_equal(false, object, message)
  end
end

def get_new_label
  label = Label.filter(I_status: Label::NEW).first
  if label.class == NilClass
    Label.new.create 1
    label = Label.filter(I_status: Label::NEW).first
  end
  label
end

def get_printed_label
  label = get_new_label
  label.change_status(Item::PRINTED, nil)
  label
end

def get_new_item
  item = Item.filter(I_status: Item::NEW).first
  if item.class == NilClass
    Label.new.create 1
    item = Item.filter(I_status: Item::NEW).first
  end
  item
end

def get_assigned_item
  DB.transaction(rollback: :always) do
    label = get_printed_label
    Product.new.get_rand.add_item label, nil
    Item[label.i_id]
  end
end
