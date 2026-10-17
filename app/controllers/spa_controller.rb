class SpaController < ActionController::Base
  def show
    entry = Rails.configuration.x.spa_entry_path

    return head :not_found unless entry && File.file?(entry)

    response.headers["Cache-Control"] = "no-cache"
    send_file entry, type: "text/html", disposition: "inline"
  end
end
