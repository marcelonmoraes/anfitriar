class CpfValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?
    record.errors.add(attribute, :invalid) unless self.class.valid?(value)
  end

  def self.valid?(value)
    digits = value.to_s.gsub(/\D/, "")
    return false unless digits.length == 11
    return false if digits.chars.uniq.one?

    [ 9, 10 ].all? { |length| digits[length].to_i == check_digit(digits[0, length]) }
  end

  def self.check_digit(partial)
    weights = (2..partial.length + 1).to_a.reverse
    sum = partial.chars.each_with_index.sum { |digit, index| digit.to_i * weights[index] }
    remainder = sum % 11
    remainder < 2 ? 0 : 11 - remainder
  end

  def self.generate(seed)
    base = format("%09d", seed % 999_999_999)
    base = "123456789" if base.chars.uniq.one?
    first = check_digit(base)
    second = check_digit("#{base}#{first}")
    "#{base}#{first}#{second}"
  end
end
