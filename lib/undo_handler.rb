# frozen_string_literal: true

# UndoHandler is the interface an object implements to register actions that
# can be undone.
#
# Ported from upstream's libview/context/pps-undo-handler.c, which is a
# GInterface with two methods. An action is an arbitrary object the handler
# invents to describe one change it made; the undo context only stores it and
# hands it back.
#
# The annotation context is the implementor upstream documents: adding an
# annotation registers an "added" action; undoing that action removes the
# annotation, which registers a "removed" action, and because the context is
# undoing at the time, the removal lands on the redo stack instead of the undo
# one.
#
module UndoHandler
  # Reverses the change the action describes. Registering the inverse change
  # back into the undo context is the implementor's job, and is what puts it
  # on the redo stack.
  def undo(_action)
    raise(NotImplementedError, "#{self.class}#undo")
  end

  # Releases whatever the action holds. Upstream's handlers free a struct
  # here; a Ruby action is garbage collected, so the default does nothing and
  # a handler holding something that needs closing overrides it.
  def free_action(_action) = nil
end
