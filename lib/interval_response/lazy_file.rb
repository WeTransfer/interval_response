# Used so that if a sequence of files
# gets served out, the files should not be kept open
# during the entire response output - as this might
# exhaust the file descriptor table
class IntervalResponse::LazyFile
  def initialize(filesystem_path)
    @fs_path = filesystem_path
  end

  def size
    File.size(@fs_path)
  end

  def with
    File.open(@fs_path, 'rb') do |file_handle|
      yield file_handle
    end
  end
end
