require "heroku/client"
require "json"
require "shellwords"
require "sinatra"
require "tmpdir"

class Heroku::Client
  def releases_new(app_name)
    json_decode(get("/apps/#{app_name}/releases/new").to_s)
  end

  def releases_create(app_name, payload)
    json_decode(post("/apps/#{app_name}/releases", json_encode(payload)))
  end

  def release(app_name, slug, description, options={})
    release = releases_new(app_name)
    RestClient.put(release["slug_put_url"], File.open(slug, "rb"), :content_type => nil)
    user = json_decode(get("/account").to_s)["email"]
    payload = release.merge({
      "slug_version" => 2,
      "run_deploy_hooks" => true,
      "user" => user,
      "release_descr" => description,
      "head" => Digest::SHA1.hexdigest(Time.now.to_f.to_s)
    }) { |k, v1, v2| v1 || v2 }.merge(options)
    releases_create(app_name, payload)
  end

  def release_slug(app_name)
    json_decode(get("/apps/#{app_name}/release_slug").to_s)
  end
end

helpers do
  def api(key, cloud="standard")
    client = Heroku::Client.new("", key)
    client.host = cloud
    client
  end

  def auth!
    response["WWW-Authenticate"] = %(Basic realm="Restricted Area")
    throw(:halt, [401, "Unauthorized"])
  end

  def creds
    auth = Rack::Auth::Basic::Request.new(request.env)
    auth.provided? && auth.basic? ? auth.credentials : auth!
  end

  def error(message)
    halt 422, { "error" => message }.to_json
  end
end

post "/apps/:app/release" do
  api_key = creds[1]

  halt(403, "must specify cloud") unless params[:cloud]
  halt(403, "must specify build_url") unless params[:build_url]
  halt(403, "must specify description") unless params[:description]

  release_from_url(api_key, params[:cloud], params[:app], params[:build_url], params[:description],params[:processes])
end

post "/apps/:app/promote" do
  api_key = creds[1]

  halt(403, "must specify cloud") unless params[:cloud]

  downstream_app = downstream_app(api_key)

  downstream_slug = api(api_key, params[:cloud]).release_slug(params[:app])
  puts api(api_key, params[:cloud]).list
  puts downstream_slug
  release_from_url(api_key, params[:cloud], downstream_app, downstream_slug["slug_url"], "Promotion from #{params[:app]} #{downstream_slug["name"]}", nil)
end

private

def downstream_app(api_key)
  if params.has_key? "DOWNSTREAM_APP"
    return params["DOWNSTREAM_APP"]
  end
  
  config_vars = api(api_key, params[:cloud]).config_vars(params[:app])
  if config_vars.has_key? "DOWNSTREAM_APP"
    return config_vars["DOWNSTREAM_APP"]
  end

  halt(403, "unknown DOWNSTREAM_APP. either set as config var on upstream app or as query param")
end

def release_from_url(api_key, cloud, app, build_url, description, processes)
  release = Dir.mktmpdir do |dir|
    escaped_build_url = Shellwords.escape(build_url)

    if build_url =~ /\.tgz$/
      %x{ mkdir -p #{dir}/tarball }
      %x{ cd #{dir}/tarball && curl #{escaped_build_url} -s -o- | tar xzf - }
      %x{ mksquashfs #{dir}/tarball #{dir}/squash -all-root }
      %x{ cp #{dir}/squash #{dir}/build }
    else
      %x{ curl #{escaped_build_url} -o #{dir}/build 2>&1 }
    end

    %x{ unsquashfs -d #{dir}/extract #{dir}/build Procfile }

    if processes
      procfile = processes
    else
      if File.exists?("#{dir}/extract/Procfile")
        procfile = File.read("#{dir}/extract/Procfile").split("\n").inject({}) do |ax, line|
          ax[$1] = $2 if line =~ /^([A-Za-z0-9_]+):\s*(.+)$/
          ax
        end
      end
    end

    release_options = {
        "process_types" => procfile
    }

    release = api(api_key, cloud).release(app, "#{dir}/build", description, release_options)
    release["release"]
  end

  content_type "application/json"
  JSON.dump({"release" => release})
end