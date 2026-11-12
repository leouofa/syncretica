Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  if Rails.env.development?
    require "sidekiq/web"
    mount Sidekiq::Web => "/sidekiq"
  end

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "pages#home"
  get "gods" => "pages#gods", as: :gods
  get "myths" => "pages#myths", as: :myths

  resources :pantheons, only: [] do
    post :populate, on: :collection
  end

  resources :gods, only: [ :show ] do
    post :populate, on: :collection
    post :generate_embedding, on: :member
  end

  resources :myths, only: [ :show ] do
    post :populate, on: :collection
    post :generate_embedding, on: :member
  end
end
