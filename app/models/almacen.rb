class Almacen < ActiveRecord::Base
  has_many :productos

  def has_space?
    if self.espacioUtilizado < espacioTotal
      return true
    else
      false
    end
  end
end
