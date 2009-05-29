require 'pp'
$: << File.expand_path(File.dirname(__FILE__) + '/../lib')
$:.uniq!

describe "test1" do
  it "should handle Factory correctly" do
  require 'ruml'
  # pp RUML::Support::Instantiable::INSTANTIABLE_CLASSES

  f = RUML::Support::Factory.new

  p1 = f.new :Property, 
  :name => :left,
  :isReadOnly => false,
  :isComposite => false,
  :isDerived => false

  p2 = f.new :Property, 
  :name => :right, 
  :isReadOnly => false,
  :isComposite => false,
  :isDerived => false

  cls1 = f.new :Class, 
  :name => :BinaryNode, 
  :isAbstract => false,
  :ownedAttribute => [ p1, p2 ]

  c1 = f.new :Comment,
  :body => "The left link of a binary tree node",
  :annotatedElement => [ p1 ],
  :owningElement => cls1

  c2 = f.new :Comment,
  :body => "The right link of a binary tree node",
  :annotatedElement => [ p2 ],
  :owningElement => cls1

  c3 = f.new :Comment,
  :body => "This is a binary tree",
  :annotatedElement => [ cls1 ],
  :owningElement => cls1

  p1.type = cls1
  p2.type = cls1

  pp c1
  $f = f
  $cls1 = cls1
  end # it
end # describe


