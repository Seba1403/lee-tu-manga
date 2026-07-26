Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "series#index"

  resources :series, only: [ :index, :show ], param: :slug

  resources :volumes, only: [ :show ] do
    member do
      get "pages/:number", to: "volumes#page", as: :page, constraints: { number: /\d+/ }
      patch :progress
    end
  end

  resource :library_scan, only: [ :create ]
  resource :session, only: [ :new, :create, :destroy ]
end
