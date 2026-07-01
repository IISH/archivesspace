class GenerateIdentifierController < ApplicationController

  if Rails.env.development?
    # https://samuelmullen.com/articles/csrf-protection-and-ruby-on-rails/
    protect_from_forgery with: :null_session
  end

  set_access_control "update_accession_record" => [:generate],
                     "update_resource_record" => [:generate]

  def generate
    object_type = params[:object_type]

    if ['ACQ', 'ARCH', 'COLL'].include?(object_type)
      url = "/plugins/generate_identifier/#{object_type}"
      response = JSONModel::HTTP::get_json(url)
      if response
        render :json => response
      else
        render :json => { "error" => 'Unknown object type. Use: ACQ, ARCH or COLL' }, :status => 500
      end
    else
      render :json => { "error" => 'Incorrect object type. Use: ACQ, ARCH or COLL' }, :status => 404
    end
  end

end
