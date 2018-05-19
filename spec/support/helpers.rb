module Helpers
  def load_dataset(name)
    dataset = File.open(File.join('spec/support/data', name), 'r') do |f|
      JSON.load(f)
    end

    id_prefix = name.split('.', 2).first

    dataset.each_with_index do |record, i|
      db.insert("#{id_prefix}_#{i}", record)
    end
  end
end
