require 'sinatra'
require 'data_mapper'
require './models.rb'

get '/topics/create' do
  topic = Topic.create(:title => params[:title])
  topic.to_json
end

get '/topics/show' do
  Topic.get(params[:id]).to_json(:methods => [:messages])
end

get '/topics/list' do
  topics = Topic.all.to_json
end

get '/topics/edit' do
  topic = Topic.get(params[:id])
  topic.title = params[:title]
  topic.save
  topic.to_json
end

get '/topics/delete' do
  topic = Topic.get(params[:id])
  topic.destroy
  'ok'
end

get '/topics/search' do
  Topic.all(:title.like => '%%%s%%' % params['title']).to_json
end

get '/messages/create' do
  topic = Topic.get(params[:topic_id])
  message = topic.messages.create(:content => params[:content])
  message.to_json
end
