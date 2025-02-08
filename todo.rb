require "sinatra"
require "sinatra/reloader"
require "tilt/erubi"

get "/" do
  erb "You have no lists.", layout: :layout
end
