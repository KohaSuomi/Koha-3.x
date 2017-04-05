#!/usr/bin/perl
package Koha::Reporting::Report::Filter::Abstract;

use Modern::Perl;
use Moose;
use Data::Dumper;
use C4::Context;

has 'name' => (
    is => 'rw',
    reader => 'getName',
    writer => 'setName'
);

has 'description' => (
    is => 'rw',
    reader => 'getDescription',
    writer => 'setDescription'
);

has 'type' => (
    is => 'rw',
    reader => 'getType',
    writer => 'setType'
);

has 'dimension' => (
    is => 'rw',
    reader => 'getDimension',
    writer => 'setDimension'
);

has 'field' => (
    is => 'rw',
    reader => 'getField',
    writer => 'setField'
);

has 'rule' => (
    is => 'rw',
    reader => 'getRule',
    writer => 'setRule'
);

has 'logic' => (
    is => 'rw',
    default => 'AND',
    reader => 'getLogic',
    writer => 'setLogic'
);

has 'options' => (
    is => 'rw',
    isa => 'ArrayRef',
    default => sub { [] },
    writer => 'setOptions'
);

has 'conditions' => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
    reader => 'getConditions',
    writer => 'setConditions'
);

has 'from_date' => (
    is => 'rw',
    reader => 'getFromDate',
    writer => 'setFromDate'
);

has 'to_date' => (
    is => 'rw',
    reader => 'getToDate',
    writer => 'setToDate'
);

sub BUILD {
    my $self = shift;
    my $conditions = {
       'eq' => '{{field}} = %s',
       'neq' => '{{field}} != %s',
       'in' => '{{field}} in ( %s )',
       'lt' => '{{field}} < %s',
       'gt' => '{{field}} > %s',
       'lte' => '{{field}} <= %s',
       'gte' => '{{field}} >= %s',
       'null' => "( {{field}} is null OR {{field}} = 'null' )"
    };
    $self->setConditions($conditions);
}

sub addCondition{
    my $self = shift;
    my $name = $_[0];
    my $condition = $_[1];

    if($name && $condition){
        $self->{conditions}->{$name} = $condition;
    }
}

sub getConditionByName{
    my $self = shift;
    my $name = $_[0];
    my $condition = 0;
    if( defined $self->{'conditions'}->{$name} ){
       $condition = $self->{'conditions'}->{$name};
    }
    return $condition;
}

sub getArrayCondition{
    my $self = shift;
    my $array = $_[0];
    my $condition = '';
    my $dbh = C4::Context->dbh;
    my $lastIndex = $#$array;
    if(@$array){
        my $lastIndex = $#$array;
        for my $i (0 .. $lastIndex) {
            $condition .= $dbh->quote(@$array[$i]);
            if($lastIndex != $i ){
                $condition .= ', ';
            }
            $i++;
        }
    }
    return $condition;
}

sub getConditionString{
    my $self = shift;
    my ($table, $options) = @_;
    my $conditionString = '';
    my $dbh = C4::Context->dbh;
    my ($value, $addNullOr);
    my $tmpOptions = [];
    my $field = $table->getTableName() . '.' . $self->getField();
    if(ref($options) eq 'ARRAY'){
        if(@$options){
            foreach my $option (@$options){
               if($option eq 'null'){
                   $addNullOr = 1;
               }
               else{
                   push $tmpOptions, $option;
               }
            }
            $options = $tmpOptions;
            if($options && @$options){
                $value = $self->getArrayCondition($options);
            }
        }
    }
    else{
        $value = $dbh->quote($options);
    }

    if(defined $value){
        $conditionString = $self->getConditionByName($self->getRule());
    }

    if($conditionString && $addNullOr){
        $conditionString = '('. $conditionString .' OR '. $self->getConditionByName('null'). ')';
    }
    elsif($addNullOr){
        $value = 1;
        $conditionString = $self->getConditionByName('null');
    }

    if($conditionString && $value){
        $conditionString =~ s/\Q{{field}}\E/$field/g;
        $conditionString = sprintf($conditionString, $value);
    }
    return $conditionString;
}

sub getOptions{
    my $self = shift; 
    my $options = $self->{options};
    if(@$options <= 0){
        $options = $self->loadOptions();
        push $options, {'name' => 'null', 'description' => 'Not set'};
    }
    return $options;
}

sub loadOptions{
    my $self = shift;
    return $self->{options};
}

sub toHash{
    my $self = shift;
    my $hash = {};

    if($self->getName() && $self->getType() && $self->getDimension() && $self->getField() && $self->getRule()){
        $hash->{name} = $self->getName();
        $hash->{description} = $self->getDescription();
        $hash->{type} = $self->getType();

        if($self->getOptions()){
            $hash->{options} = $self->getOptions();
        }
    }
    return $hash;
}

sub modifyOptions{
    my $self = shift;
    my $options = $_[0];
    return $options;
}


1;
