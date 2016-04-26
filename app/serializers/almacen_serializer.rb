class AlmacenSerializer < ActiveModel::Serializer
  attributes :id, :espacioUtilizado, :espacioTotal, :recepcion, :despacho, :pulmon
end
