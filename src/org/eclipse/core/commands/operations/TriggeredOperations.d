/*******************************************************************************
 * Copyright (c) 2005, 2006 IBM Corporation and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * Contributors:
 *     IBM Corporation - initial API and implementation
 * Port to the D programming language:
 *     Frank Benoit <benoit@tionex.de>
 *******************************************************************************/
module org.eclipse.core.commands.operations.TriggeredOperations;

import org.eclipse.core.commands.ExecutionException;
import org.eclipse.core.runtime.IAdaptable;
import org.eclipse.core.runtime.IProgressMonitor;
import org.eclipse.core.runtime.IStatus;
import org.eclipse.core.runtime.OperationCanceledException;
import org.eclipse.core.runtime.Status;

import org.eclipse.core.commands.operations.AbstractOperation;
import org.eclipse.core.commands.operations.ICompositeOperation;
import org.eclipse.core.commands.operations.IAdvancedUndoableOperation;
import org.eclipse.core.commands.operations.IContextReplacingOperation;
import org.eclipse.core.commands.operations.IUndoableOperation;
import org.eclipse.core.commands.operations.IOperationHistory;
import org.eclipse.core.commands.operations.IUndoContext;
import org.eclipse.core.commands.operations.OperationHistoryEvent;

import java.lang.all;

import java.util.List;
import java.util.ArrayList;

/**
 * Triggered operations are a specialized implementation of a composite
 * operation that keeps track of operations triggered by the execution of some
 * primary operation. The composite knows which operation was the trigger for
 * subsequent operations, and adds all triggered operations as children. When
 * execution, undo, or redo is performed, only the triggered operation is
 * executed, undone, or redone if it is still present. If the trigger is removed
 * from the triggered operations, then the child operations will replace the
 * triggered operations in the history.
 * <p>
 * This class may be instantiated by clients.
 * </p>
 *
 * @since 3.1
 */
public final class TriggeredOperations : AbstractOperation,
        ICompositeOperation, IAdvancedUndoableOperation,
        IContextReplacingOperation {

    private IUndoableOperation triggeringOperation;

    private IOperationHistory history;

    private List children;

    /**
     * Construct a composite triggered operations using the specified undoable
     * operation as the trigger. Use the label of this trigger as the label of
     * the operation.
     *
     * @param operation
     *            the operation that will trigger other operations.
     * @param history
     *            the operation history containing the triggered operations.
     */
    public this(IUndoableOperation operation,
            IOperationHistory history) {
        super(operation.getLabel());
        children = new ArrayList();
        triggeringOperation = operation;
        recomputeContexts();
        this.history = history;
    }

    /*
     * (non-Javadoc)
     *
     * @see org.eclipse.core.commands.operations.IUndoableOperation#add(org.eclipse.core.commands.operations.IUndoableOperation)
     */
    public void add(IUndoableOperation operation) {
        children.add(cast(Object)operation);
        recomputeContexts();
    }

    /*
     * (non-Javadoc)
     *
     * @see org.eclipse.core.commands.operations.IUndoableOperation#remove(org.eclipse.core.commands.operations.IUndoableOperation)
     */
    public void remove(IUndoableOperation operation) {
        if (operation is triggeringOperation) {
            // the triggering operation is being removed, so we must replace
            // this composite with its individual triggers.
            triggeringOperation = null;
            // save the children before replacing the operation, since this
            // operation will be disposed as part of replacing it. We don't want
            // the children to be disposed since they are to replace this
            // operation.
            List childrenToRestore = new ArrayList(children);
            children = new ArrayList(0);
            recomputeContexts();
            operation.dispose();
            // now replace the triggering operation
            history.replaceOperation(this, arraycast!(IUndoableOperation)(childrenToRestore.toArray()));
        } else {
            children.remove(cast(Object)operation);
            operation.dispose();
            recomputeContexts();
        }
    }

    /**
     * Remove the specified context from the receiver. This method is typically
     * invoked when the history is being flushed for a certain context. In the
     * case of triggered operations, if the only context for the triggering
     * operation is being removed, then the triggering operation must be
     * replaced in the operation history with the atomic operations that it
     * triggered. If the context being removed is not the only context for the
     * triggering operation, the triggering operation will remain, and the
     * children will each be similarly checked.
     *
     * @param context
     *            the undo context being removed from the receiver.
     */
    public override void removeContext(IUndoContext context) {

        bool recompute = false;
        // first check to see if we are removing the only context of the
        // triggering operation
        if (triggeringOperation !is null
                && triggeringOperation.hasContext(context)) {
            if (triggeringOperation.getContexts().length is 1) {
                remove(triggeringOperation);
                return;
            }
            triggeringOperation.removeContext(context);
            recompute = true;
        }
        // the triggering operation remains, check all the children
        auto toBeRemoved = new ArrayList();
        for (int i = 0; i < children.size(); i++) {
            IUndoableOperation child = cast(IUndoableOperation) children.get(i);
            if (child.hasContext(context)) {
                if (child.getContexts().length is 1) {
                    toBeRemoved.add(cast(Object)child);
                } else {
                    child.removeContext(context);
                }
                recompute = true;
            }
        }
        for (int i = 0; i < toBeRemoved.size(); i++) {
            remove(cast(IUndoableOperation) toBeRemoved.get(i));
        }
        if (recompute) {
            recomputeContexts();
        }
    }

    /*
     * (non-Javadoc)
     *
     * @see org.eclipse.core.commands.operations.IUndoableOperation#execute(org.eclipse.core.runtime.IProgressMonitor,
     *      org.eclipse.core.runtime.IAdaptable)
     */
    public override IStatus execute(IProgressMonitor monitor, IAdaptable info) {
        if (triggeringOperation !is null) {
            history.openOperation(this, IOperationHistory.EXECUTE);
            try {
                IStatus status = triggeringOperation.execute(monitor, info);
                history.closeOperation(status.isOK(), false,
                        IOperationHistory.EXECUTE);
                return status;
            } catch (ExecutionException e) {
                history.closeOperation(false, false, IOperationHistory.EXECUTE);
                throw e;
            } catch (RuntimeException e) {
                history.closeOperation(false, false, IOperationHistory.EXECUTE);
                throw e;
            }

        }
        return IOperationHistory.OPERATION_INVALID_STATUS;
    }

    /*
     * (non-Javadoc)
     *
     * @see org.eclipse.core.commands.operations.IUndoableOperation#redo(org.eclipse.core.runtime.IProgressMonitor,
     *      org.eclipse.core.runtime.IAdaptable)
     */
    public override IStatus redo(IProgressMonitor monitor, IAdaptable info) {
        if (triggeringOperation !is null) {
            history.openOperation(this, IOperationHistory.REDO);
            List childrenToRestore = new ArrayList(children);
            try {
                removeAllChildren();
                IStatus status = triggeringOperation.redo(monitor, info);
                if (!status.isOK()) {
                    children = childrenToRestore;
                }
                history.closeOperation(status.isOK(), false,
                        IOperationHistory.REDO);
                return status;
            } catch (ExecutionException e) {
                children = childrenToRestore;
                history.closeOperation(false, false, IOperationHistory.REDO);
                throw e;
            } catch (RuntimeException e) {
                children = childrenToRestore;
                history.closeOperation(false, false, IOperationHistory.REDO);
                throw e;
            }
        }
        return IOperationHistory.OPERATION_INVALID_STATUS;
    }

    /*
     * (non-Javadoc)
     *
     * @see org.eclipse.core.commands.operations.IUndoableOperation#undo(org.eclipse.core.runtime.IProgressMonitor,
     *      org.eclipse.core.runtime.IAdaptable)
     */
    public override IStatus undo(IProgressMonitor monitor, IAdaptable info) {
        if (triggeringOperation !is null) {
            history.openOperation(this, IOperationHistory.UNDO);
            List childrenToRestore = new ArrayList(children);
            try {
                removeAllChildren();
                IStatus status = triggeringOperation.undo(monitor, info);
                if (!status.isOK()) {
                    children = childrenToRestore;
                }
                history.closeOperation(status.isOK(), false,
                        IOperationHistory.UNDO);
                return status;
            } catch (ExecutionException e) {
                children = childrenToRestore;
                history.closeOperation(false, false, IOperationHistory.UNDO);
                throw e;
            } catch (RuntimeException e) {
                children = childrenToRestore;
                history.closeOperation(false, false, IOperationHistory.UNDO);
                throw e;
            }
        }
        return IOperationHistory.OPERATION_INVALID_STATUS;
    }

    /*
     * (non-Javadoc)
     *
     * @see org.eclipse.core.commands.operations.IUndoableOperation#canUndo()
     */
    public override bool canUndo() {
        if (triggeringOperation !is null) {
            return triggeringOperation.canUndo();
        }
        return false;
    }

    /*
     * (non-Javadoc)
     *
     * @see org.eclipse.core.commands.operations.IUndoableOperation#canExecute()
     */
    public override bool canExecute() {
        if (triggeringOperation !is null) {
            return triggeringOperation.canExecute();
        }
        return false;
    }

    /*
     * (non-Javadoc)
     *
     * @see org.eclipse.core.commands.operations.IUndoableOperation#canRedo()
     */
    public override bool canRedo() {
        if (triggeringOperation !is null) {
            return triggeringOperation.canRedo();
        }
        return false;
    }

    /*
     * Dispose all operations in the receiver.
     */
    public override void dispose() {
        for (int i = 0; i < children.size(); i++) {
            (cast(IUndoableOperation)children.get(i)).dispose();
        }
        if (triggeringOperation !is null) {
            triggeringOperation.dispose();
        }
    }

    /*
     * Recompute contexts in light of some change in the children
     */
    private void recomputeContexts() {
        ArrayList allContexts = new ArrayList();
        if (triggeringOperation !is null) {
            IUndoContext[] contexts = triggeringOperation.getContexts();
            for (int i = 0; i < contexts.length; i++) {
                allContexts.add(cast(Object)contexts[i]);
            }
        }
        for (int i = 0; i < children.size(); i++) {
            IUndoContext[] contexts = (cast(IUndoableOperation)children.get(i))
                    .getContexts();
            for (int j = 0; j < contexts.length; j++) {
                if (!allContexts.contains(cast(Object)contexts[j])) {
                    allContexts.add(cast(Object)contexts[j]);
                }
            }
        }
        contexts = allContexts;

    }

    /*
     * Remove all non-triggering children
     */
    private void removeAllChildren() {
        IUndoableOperation[] nonTriggers = arraycast!(IUndoableOperation)(children
                .toArray());
        for (int i = 0; i < nonTriggers.length; i++) {
            children.remove(cast(Object)nonTriggers[i]);
            nonTriggers[i].dispose();
        }
    }

    /**
     * Return the operation that triggered the other operations in this
     * composite.
     *
     * @return the IUndoableOperation that triggered the other children.
     */
    public IUndoableOperation getTriggeringOperation() {
        return triggeringOperation;
    }

    /*
     * (non-Javadoc)
     *
     * @see org.eclipse.core.commands.operations.IAdvancedModelOperation#getAffectedObjects()
     */
    public Object[] getAffectedObjects() {
        if ( auto trg = cast(IAdvancedUndoableOperation)triggeringOperation  ) {
            return trg
                    .getAffectedObjects();
        }
        return null;
    }

    /*
     * (non-Javadoc)
     *
     * @see org.eclipse.core.commands.operations.IAdvancedModelOperation#aboutToNotify(org.eclipse.core.commands.operations.OperationHistoryEvent)
     */
    public void aboutToNotify(OperationHistoryEvent event) {
        if ( auto trg = cast(IAdvancedUndoableOperation)triggeringOperation ) {
            trg.aboutToNotify(event);
        }
    }

    /*
     * (non-Javadoc)
     *
     * @see org.eclipse.core.commands.operations.IAdvancedUndoableOperation#computeUndoableStatus(org.eclipse.core.runtime.IProgressMonitor)
     */
    public IStatus computeUndoableStatus(IProgressMonitor monitor) {
        if ( auto trg = cast(IAdvancedUndoableOperation)triggeringOperation ) {
            try {
                return trg.computeUndoableStatus(monitor);
            } catch (OperationCanceledException e) {
                return Status.CANCEL_STATUS;
            }
        }
        return Status.OK_STATUS;

    }

    /*
     * (non-Javadoc)
     *
     * @see org.eclipse.core.commands.operations.IAdvancedUndoableOperation#computeRedoableStatus(org.eclipse.core.runtime.IProgressMonitor)
     */
    public IStatus computeRedoableStatus(IProgressMonitor monitor) {
        if ( auto trg = cast(IAdvancedUndoableOperation)triggeringOperation ) {
            try {
                return trg.computeRedoableStatus(monitor);
            } catch (OperationCanceledException e) {
                return Status.CANCEL_STATUS;
            }
        }
        return Status.OK_STATUS;

    }

    /**
     * Replace the undo context of the receiver with the provided replacement
     * undo context. In the case of triggered operations, all contained
     * operations are checked and any occurrence of the original context is
     * replaced with the new undo context.
     * <p>
     * This message has no effect if the original undo context is not present in
     * the receiver.
     *
     * @param original
     *            the undo context which is to be replaced
     * @param replacement
     *            the undo context which is replacing the original
     * @since 3.2
     */
    public void replaceContext(IUndoContext original, IUndoContext replacement) {

        // first check the triggering operation
        if (triggeringOperation !is null
                && triggeringOperation.hasContext(original)) {
            if ( auto trg = cast(IContextReplacingOperation)triggeringOperation ) {
                trg.replaceContext(original, replacement);
            } else {
                triggeringOperation.removeContext(original);
                triggeringOperation.addContext(replacement);
            }
        }
        // Now check all the children
        for (int i = 0; i < children.size(); i++) {
            IUndoableOperation child = cast(IUndoableOperation)children.get(i);
            if (child.hasContext(original)) {
                if ( auto c = cast(IContextReplacingOperation)child ) {
                    c.replaceContext(
                            original, replacement);
                } else {
                    child.removeContext(original);
                    child.addContext(replacement);
                }
            }
        }
        recomputeContexts();
    }

    /**
     * Add the specified context to the operation. Overridden in
     * TriggeredOperations to add the specified undo context to the triggering
     * operation.
     *
     * @param context
     *            the context to be added
     *
     * @since 3.2
     */
    public override void addContext(IUndoContext context) {
        if (triggeringOperation !is null) {
            triggeringOperation.addContext(context);
            recomputeContexts();
        }
    }

}
