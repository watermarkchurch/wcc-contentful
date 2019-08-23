# frozen_string_literal: true

module WCC::Contentful::App::PreviewPassword
  def preview?
    # check ApplicationController for a :preview? method
    return super if defined?(super)

    @preview ||=
      if preview_password.present?
        params[:preview]&.chomp == preview_password.chomp
      else
        false
      end
  end

  def preview_password
    WCC::Contentful::App.configuration.preview_password
  end
end
