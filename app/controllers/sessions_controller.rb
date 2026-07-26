class SessionsController < ApplicationController
  def new
  end

  def create
    user = User.find_by(username: params[:username].to_s)

    if user&.authenticate(params[:password].to_s)
      reset_session
      session[:owner_authenticated] = true
      redirect_to root_path, notice: "Sesión iniciada."
    else
      flash.now[:alert] = "Usuario o contraseña incorrectos."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "Sesión cerrada."
  end
end
