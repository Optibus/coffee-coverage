# Visitor which looks for pragma directives for skipping coverage, and marks coffee-script nodes
# to be skipped.
#

_ = require 'lodash'
NodeWrapper = require './NodeWrapper'

PRAGMA_PREFIX = '!pragma'

toLocString = (node) ->
    return "(#{node.locationData.first_line + 1}:#{node.locationData.first_column + 1})"

# Verify the given node has a `next`.
getNext = (node, match, type=null) ->
    next = node.next()
    if !next?
        throw new Error "Pragma '#{match[0]}' at #{toLocString node} has no next statement"
    if type? and next.type isnt type
        throw new Error "Statement after pragma '#{match[0]}' at #{toLocString node} is not of type #{type}"
    next


PRAGMAS = [
    # '!pragma coverage-skip'
    #
    # Mark the next node and all descendants as `skip`.
    {
        regex: /^!pragma\s+coverage-skip$/
        istanbulRegex: /^istanbul\s+ignore\s+next$/
        fn: (node, match, options={}) ->
            getNext(node, match).markAll 'skip', true
    }

    # '!pragma coverage-skip-if'
    #
    # Must be before an `If` statement.  Mark the `If` as `skipIf`, and mark all children in
    # the `body` as `skip`.
    {
        regex: /^!pragma\s+coverage-skip-if$/
        istanbulRegex: /^istanbul\s+ignore\s+if$/
        fn: (node, match, options={}) ->
            ifNode = getNext(node, match, 'If')
            ifNode.node.coffeeCoverage ?= {}
            ifNode.node.coffeeCoverage.skipIf = true
            ifNode.child('body')?.markAll 'skip', true
    }

    # '!pragma coverage-skip-else'
    #
    # Must be before an `If` statement.  Mark the `If` as `skipElse`, and mark all children in
    # the `elseBody` as `skip`.
    {
        regex: /^!pragma\s+coverage-skip-else$/
        istanbulRegex: /^istanbul\s+ignore\s+else$/
        fn: (node, match, options={}) ->
            ifNode = getNext(node, match, 'If')
            ifNode.node.coffeeCoverage ?= {}
            ifNode.node.coffeeCoverage.skipElse = true
            ifNode.child('elseBody')?.markAll 'skip', true
    }

    # TODO: How do we deal with skipping cases in a `switch`?
]

module.exports = class SkipVisitor
    # `options` is a `{log}` object.
    constructor: (@options) ->

    visitComment: (node) ->
        comment = node.node.comment?.trim().toLowerCase() ? ''
        found = false
        if _.startsWith(comment, PRAGMA_PREFIX)
            PRAGMAS.forEach (pragma) =>
                if match = comment.match(pragma.regex)
                    pragma.fn node, match, @options
        else if _.startsWith(comment, 'istanbul')
            PRAGMAS.forEach (pragma) =>
                if match = comment.match(pragma.istanbulRegex)
                    pragma.fn node, match, @options
