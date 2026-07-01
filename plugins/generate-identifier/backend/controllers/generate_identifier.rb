require 'time'

class ArchivesSpaceService < Sinatra::Base

  Endpoint.get('/plugins/generate_identifier/:object_type')
          .description("Generate a new identifier based on the record type and last number in it's sequence")
          .params(["object_type", String, "The archival type: ACQ, ARCH or COLL", { :validation => ["The object type must be either ACQ, ARCH or COLL", ->(v) { ['ACQ', 'ARCH', 'COLL'].include?(v) }] }])
          .permissions([])
          .returns([200, "A number"]) \
  do

    object_type = params[:object_type]
    identifier = identifier_from_database(object_type)

    json_response({ :object_type => object_type, :identifier => identifier })
  end

  def identifier_from_database(object_type)
    table = (object_type === 'ACQ') ? 'accession' : 'resource'

    DB.open do |db|
      query = "SELECT LPAD( IFNULL( ( SELECT MAX(CAST(REGEXP_REPLACE(identifier, '[a-zA-Z,\"\\\\[\\\\]]+', '') AS SIGNED))+1 FROM #{table} WHERE identifier LIKE '%#{object_type}%' ), 1), 5, '0');"
      recordset = db.fetch(query)
      return recordset.first.first[1]
    end

    "00000"

  end

end