require 'narray'

#
# Convert a sparse matrix -- represented as a hash with [x, y] pairs as keys
# -- to a regular matrix, NMatrix. Empty cells are filled with default_value
#
def sparse_table_to_table(sparse_table, default_value)
  x_values = sparse_table.keys.map{ |x| x[0] }.sort.uniq
  y_values = sparse_table.keys.map{ |x| x[1] }.sort.uniq
  
  matrix = NMatrix.object(x_values.size + 1, y_values.size + 1)
  matrix[1..x_values.size, 0] = x_values
  matrix[0, 1..y_values.size] = y_values  
  
  # sparse_table.each do |x, y|
  # end
  
  1.upto(x_values.size) do |i|
    1.upto(y_values.size) do |j|
      xname = x_values[i - 1]
      yname = y_values[j - 1]
      matrix[i, j] = sparse_table[[xname, yname]] || default_value
    end
  end
  
  return matrix
end

#
# Given an array, create a hash that maps an element to its index in the array
#
def create_index(array)
  h = Hash.new
  array.each_with_index { |elem, index| h[elem] = index }
  return h
end
