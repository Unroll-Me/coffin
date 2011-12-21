vows        = require 'vows'
assert      = require 'assert'
fs          = require 'fs'
path        = require 'path'
coffin = require '../lib/coffin'

@assertListsEqual = (actualList, expectedList) ->
  assert.equal actualList.length, expectedList.length
  for key, val of expectedList
    for k, v of val.Properties
      assert.deepEqual actualList[key].Properties[k], v
    expected = {}
    expected[key] = val
    actual = {}
    actual[key] = actualList[key]
    assert.deepEqual actual, expected
  assert.deepEqual expectedList, actualList

suite = vows.describe 'Template Test Suite'
suite.addBatch
  'when parsing WordPressTemplate.coffee':
    topic: ->
      raw = ''
      input = fs.createReadStream path.normalize '../examples/WordPress-1.0.0.template.original'
      input.on 'data', (d) =>
        raw += "#{d}"
      input.on 'end', =>
        generatedTemplate = require('../examples/WordPress-1.0.0.template.coffee')
        originalTemplate = JSON.parse(raw)
        #console.log "generatedTemplate - #{JSON.stringify(generatedTemplate).length}, originalTemplate - #{JSON.stringify(originalTemplate).length}"
        @callback originalTemplate, generatedTemplate
      return
    'Descriptions are the same': (originalTemplate, generatedTemplate) =>
      return if originalTemplate is null or generatedTemplate is null
      assert.equal generatedTemplate.Description, originalTemplate.Description
    'Parameters are the same': (originalTemplate, generatedTemplate) =>
      return if originalTemplate is null or generatedTemplate is null
      @assertListsEqual generatedTemplate.Parameters, originalTemplate.Parameters
    'Mappings are the same': (originalTemplate, generatedTemplate) =>
      return if originalTemplate is null or generatedTemplate is null
      @assertListsEqual generatedTemplate.Mappings, originalTemplate.Mappings
    'Resources are the same': (originalTemplate, generatedTemplate) =>
      return if originalTemplate is null or generatedTemplate is null
      @assertListsEqual generatedTemplate.Resources, originalTemplate.Resources
    'Outputs are the same': (originalTemplate, generatedTemplate) =>
      return if originalTemplate is null or generatedTemplate is null
      @assertListsEqual generatedTemplate.Outputs, originalTemplate.Outputs
  'when using resource types':
    topic: ->
      coffin ->
        @AWS.AutoScaling.ScalingPolicy 'scalePolicy'
        @Param.String 'shortParam'
    'it does not break': (topic) ->
      assert.ok topic?
      assert.ok topic.Parameters?
      assert.ok topic.Resources?
      assert.ok topic.Outputs?
    'scaling policy is good': (topic) ->
      assert.ok topic.Resources.scalePolicy?
    'short param is good': (topic) ->
      assert.ok topic.Parameters.shortParam?
  'when using a blank template':
    topic: ->
      coffin ->
    'it is not null': (topic) ->
      assert.ok topic?
    'there is no description': (topic) ->
      assert.ok Object.keys(topic).indexOf('Description') is -1
    'there is no mappings block': (topic) ->
      assert.ok Object.keys(topic).indexOf('Mappings') is -1
    'there is a Parameters block': (topic) ->
      assert.ok topic.Parameters?
    'there is a Resources block': (topic) ->
      assert.ok topic.Resources?
    'there is a Outputs block': (topic) ->
      assert.ok topic.Outputs?
  'when using mappings':
    topic: ->
      coffin ->
        @Mapping 'AWSRegionArch2AMI'
          'us-east-1':
            32: "ami-f417e49d"
            64: "ami-f617e49f"
    'mappings block exists': (topic) ->
      assert.ok topic.Mappings?
    'values exist': (topic) ->
      assert.equal 'ami-f417e49d', topic.Mappings.AWSRegionArch2AMI['us-east-1']['32']
      assert.equal 'ami-f617e49f', topic.Mappings.AWSRegionArch2AMI['us-east-1']['64']
  'when using tags':
    topic: ->
      coffin ->
        @AWS.EC2.Instance 'instance',
          Tags: [ @Tag('Name', 'someInstance'), @Tag('Environment', 'someEnvironment') ]
    'tags are correct': (topic) ->
      assert.equal 'Name', topic.Resources.instance.Properties.Tags[0].Key
      assert.equal 'someInstance', topic.Resources.instance.Properties.Tags[0].Value
      assert.equal 'Environment', topic.Resources.instance.Properties.Tags[1].Key
      assert.equal 'someEnvironment', topic.Resources.instance.Properties.Tags[1].Value
  'when using the join function':
    topic: ->
      myArray = ['x', 'y', 'z']
      coffin ->
        @AWS.EC2.Instance 'a',
          UserData: @Join '', 'x', 'y', 'z'
        @AWS.EC2.Instance 'b',
          UserData: @Join '', myArray
    'it works with varargs': (topic) ->
      assert.equal topic.Resources.a.Properties.UserData['Fn::Join'][0], ''
      assert.deepEqual topic.Resources.a.Properties.UserData['Fn::Join'][1], ['x', 'y', 'z']
    'it works with an array arg': (topic) ->
      assert.equal topic.Resources.b.Properties.UserData['Fn::Join'][0], ''
      assert.deepEqual topic.Resources.b.Properties.UserData['Fn::Join'][1], ['x', 'y', 'z']
  'when using metadata and top level properties':
    topic: ->
      coffin ->
        @AWS.EC2.Instance 'a',
          Metadata:
            meta: 'data'
          Properties:
            a: 'b'
    'metadata block is correct': (topic) ->
      assert.ok topic.Resources.a.Metadata?
      assert.equal topic.Resources.a.Metadata.meta, 'data'
    'properties block is correct': (topic) ->
      assert.ok topic.Resources.a.Properties?
      assert.equal topic.Resources.a.Properties.a, 'b'
  'when using @InitScript':
    topic: ->
      coffin ->
        @AWS.EC2.Instance 'a',
          @InitScript '''
#!/bin/bash
echo "hey"
'''
        @AWS.EC2.Instance 'b',
          @InitScript 'init_script.sh'
    'we are able to embed a nice shell script inline': (topic) ->
      assert.ok topic.Resources.a.Properties.UserData?["Fn::Base64"]?["Fn::Join"]?
      assert.equal 1, topic.Resources.a.Properties.UserData["Fn::Base64"]["Fn::Join"][1].length
    'we are able to include a nice shell script file': (topic) ->
      assert.ok topic.Resources.a.Properties.UserData?["Fn::Base64"]?["Fn::Join"]?
      assert.equal 1, topic.Resources.a.Properties.UserData["Fn::Base64"]["Fn::Join"][1].length

suite.run()
