class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :owner_signed_in?

  private

  def owner_signed_in?
    session[:owner_authenticated].present?
  end

  def require_owner!
    redirect_to new_session_path, alert: "Necesitas iniciar sesión para hacer esto." unless owner_signed_in?
  end
end
