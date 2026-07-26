# Crea o actualiza el único usuario dueño de la app a partir de variables de
# entorno, para no tener que tocar la base de datos a mano. Se puede volver a
# correr (bin/rails db:seed) para rotar la contraseña más adelante.
if ENV["OWNER_USERNAME"].present? && ENV["OWNER_PASSWORD"].present?
  user = User.find_or_initialize_by(username: ENV["OWNER_USERNAME"])
  user.password = ENV["OWNER_PASSWORD"]
  user.save!
end
