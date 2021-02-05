module EngineTemplate
  module Actions


    def prepend_in_file(relative_path, str)
      path = File.join(destination_root, relative_path)

      new_contents = str + IO.read(path)
      # File.open(file, 'r') do |fd|
      #   contents = fd.read
      #   new_contents = str << contents
      # end
      # Overwrite file but now with prepended string on it
      File.open(path, 'w') do |fd|
        fd.write(new_contents)
      end
    end
  end
end
