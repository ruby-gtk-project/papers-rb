# frozen_string_literal: true

require 'adwaita'
require_relative 'document_model'
require_relative 'undo_handler'

# UndoContext is the undo and redo stacks for the open document.
#
# Ported from upstream's libview/context/pps-undo-context.c. Handlers (the
# annotation context, for one) register an action for each change they make;
# an undo pops the newest action and asks its handler to reverse it, and the
# inverse action the handler registers while that is happening lands on the
# redo stack rather than back on the undo stack. Changing the document clears
# both stacks, because the actions describe changes to a document that is no
# longer open.
#
class UndoContext < GLib::Object
  type_register

  STATE_NORMAL = :normal
  STATE_UNDOING = :undoing
  STATE_REDOING = :redoing

  # Emitted whenever either stack changes, with the handler that registered
  # the action, so a window can re-evaluate its undo and redo actions.
  define_signal(
    'stacks_changed',
    GLib::Signal::RUN_LAST,
    nil,
    nil,
    GLib::Object,
  )

  install_property(
    GLib::Param::Object.new(
      'document-model',
      'Document Model',
      'The document model associated with this undo context',
      DocumentModel,
      GLib::Param::READWRITE,
    ),
  )

  # One registered change: the handler that made it, and the handler's own
  # description of it.
  Action = Struct.new(:handler, :data)

  attr_reader :document_model

  def initialize(document_model)
    super()
    @undo_stack = []
    @redo_stack = []
    @undo_state = STATE_NORMAL
    @document_model = document_model

    document_model.signal_connect('notify::document') { document_changed }
  end

  def signal_do_stacks_changed(_handler) = nil

  def can_undo? = !@undo_stack.empty?
  def can_redo? = !@redo_stack.empty?

  # While undoing, a newly registered action is the inverse of the one being
  # undone and belongs on the redo stack. While doing anything else, it is a
  # fresh change, so the redo stack no longer applies and is dropped.
  def add_action(handler, data)
    target_stack.tap do |stack|
      if @undo_state == STATE_NORMAL
        clear(@redo_stack)
      end

      stack.unshift(Action.new(handler, data))
      signal_emit('stacks-changed', handler)
    end
  end

  def undo
    @undo_stack.shift.then do |action|
      unless action.nil?
        apply(action, STATE_UNDOING)
      end
    end
  end

  def redo
    @redo_stack.shift.then do |action|
      unless action.nil?
        apply(action, STATE_REDOING)
      end
    end
  end

  # The handler on top of the undo stack. Upstream's annotation context uses
  # this to append to the action it registered a moment ago rather than
  # registering a second one; new code should register one complete action per
  # user action instead.
  def last_handler
    @undo_stack.first&.handler
  end

  # The newest action on whichever stack is currently being added to.
  def last_action
    target_stack.first&.data
  end

  private

    def target_stack
      if @undo_state == STATE_UNDOING
        @redo_stack
      else
        @undo_stack
      end
    end

    # Reversing an action runs with the state set, so whatever the handler
    # registers in response goes onto the opposite stack.
    def apply(action, state)
      @undo_state = state
      action.handler.undo(action.data)
      action.handler.free_action(action.data)
      @undo_state = STATE_NORMAL
    end

    def document_changed
      clear(@undo_stack)
      clear(@redo_stack)
    end

    def clear(stack)
      stack.each { |action| action.handler.free_action(action.data) }
      stack.clear
    end
end
