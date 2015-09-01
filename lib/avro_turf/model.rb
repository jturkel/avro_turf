class AvroTurf
  class Model

    class << self
      attr_reader :schema

      def build(avro, schema_name: nil, schema: nil)
        schema ||= avro.find_schema(schema_name)

        Class.new(self) do
          @avro = avro
          @schema = schema

          schema.fields.each do |field|
            type = field.type

            attr_accessor field.name

            case type.type_sym
            when :enum
              type.symbols.each do |symbol|
                const_set(symbol.upcase, symbol)
              end
            when :record
              klass = build(avro, schema: type)

              # hello_world -> HelloWorld
              klass_name = type.name.
                split("_").
                map {|word| word[0] = word[0].upcase; word }.
                join

              const_set(klass_name, klass)

              define_method("#{field.name}=") do |value|
                instance_variable_set("@#{field.name}", klass.new(value))
              end
            end
          end
        end
      end

      def encode(instance)
        @avro.encode(instance, schema_name: @schema.name)
      end

      def decode(data)
        new(@avro.decode(data, schema_name: @schema.name))
      end
    end

    def initialize(attributes = nil)
      attributes.each do |attr, value|
        if respond_to?("#{attr}=")
          send("#{attr}=", value)
        else
          raise ArgumentError, "no such attribute `#{attr}`"
        end
      end
    end

    def ==(other)
      self.class.schema.fields.all? {|field|
        self.send(field.name) == other.send(field.name)
      }
    end

    def as_avro
      self.class.schema.fields.each_with_object(Hash.new) do |field, hsh|
        hsh[field.name] = send(field.name).as_avro
      end
    end

    def encode
      self.class.encode(self)
    end
  end
end