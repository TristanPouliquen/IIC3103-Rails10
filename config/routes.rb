Rails.application.routes.draw do
  root 'pages#index'
  get '/spree/checkout/gateway_landing/:order_number' => 'spree/checkout#process_gateway_return', :as => 'gateway_landing'
  get '/spree/admin/checkout/gateway_landing/:order_number' => 'spree/admin/payments#process_gateway_return', :as => 'admin_gateway_landing'
  get '/spree/checkout/process_payment/:order_number' => 'spree/checkout#process_payment', :as => 'process_payment'
  get '/spree/checkout/process_payment/:order_number' => 'spree/admin/payments#process_payment', :as => 'admin_process_payment'
  # patch '/spree/checkout/update/delivery' => 'spree#spreePay'
  # get 'spree/order/:factura/success' => 'spree#success'
  # get 'spree/order/:factura/failure' => 'spree#failure'

  mount Spree::Core::Engine, at: '/spree'

  get '/business-intelligence' => 'pages#businessIntelligence'
  get '/bi/day-transactions/:date' => 'pages#dayTransactions'

  scope :path => '/bodega' do
    get '/' => 'pages#home'

    get 'bodegas' => 'pages#warehouses'

    scope :path=> '/admin' do
      get 'index' => "admin#index"
      get 'produccion' => "admin#production"
      post 'produce' => "admin#produce"
      get 'compras' => "admin#purchases"
      post 'purchase' => 'admin#purchase'
      post 'move' => 'bodega#move'
      get 'cartola' => 'admin#account'
    end
  end

  scope :path => '/api' do
    get 'consultar/:sku' => 'api#getStockWithSku'
    get 'oc/recibir/:idoc' => 'api#receivePurchaseOrder'
    get '/oc/recibir/internacional/:idoc' => 'api#receivePurchaseOrder'
    get 'facturas/recibir/:idfactura' => 'api#receiveBill'
    get 'pagos/recibir/:idtrx' => 'api#receivePayment'
    get 'datos' => 'api#getDatos'
    get 'saldo' => 'api#getAccount' #to test the good connection to the general system service
  end

 end
