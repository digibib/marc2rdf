#encoding: utf-8
# patched Struct and Hash classes to allow easy conversion to/from JSON and Hash
class Struct
  def to_map
    map = Hash.new
    self.members.each { |m| map[m] = self[m] }
    # strip out empty struct values and nils
    map.reject! {|k,v| v.strip.empty? if v.is_a?(String) && v.respond_to?('empty?') ; v.nil?}
    map
  end
  def to_json(*a)
    to_map.to_json(*a)
  end
end

class Hash
  def to_struct(name)
    cls = Struct.const_get(name) rescue Struct.new(name, *keys)
    struct = cls.new
    struct.members.each {|k| struct[k] = self[k.to_s]}
    struct
  end
  
  # remove empty params from params Hash
  def remove_empty_params!
    self.delete_if {|k,v| v.respond_to?(:empty?) && v.empty? }
  end
end
