/*******************************************************************************
 * Copyright (c) 2004, 2008 IBM Corporation and others.
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
module org.eclipse.core.commands.Command;

// import java.io.BufferedWriter;
// import java.io.IOException;
// import java.io.StringWriter;

import org.eclipse.core.commands.common.NotDefinedException;
import org.eclipse.core.commands.util.Tracing;
import org.eclipse.core.internal.commands.util.Util;
import org.eclipse.core.runtime.ISafeRunnable;
import org.eclipse.core.runtime.ListenerList;
import org.eclipse.core.runtime.SafeRunner;

import org.eclipse.core.commands.IParameter;
import org.eclipse.core.commands.IHandlerListener;
import org.eclipse.core.commands.NotEnabledException;
import org.eclipse.core.commands.NotHandledException;
import org.eclipse.core.commands.ExecutionException;
import org.eclipse.core.commands.CommandEvent;
import org.eclipse.core.commands.State;
import org.eclipse.core.commands.Category;
import org.eclipse.core.commands.NamedHandleObjectWithState;
import org.eclipse.core.commands.ExecutionEvent;
import org.eclipse.core.commands.ParameterType;
import org.eclipse.core.commands.IExecutionListener;
import org.eclipse.core.commands.ICommandListener;
import org.eclipse.core.commands.IHandler;
import org.eclipse.core.commands.IHandler2;
import org.eclipse.core.commands.IObjectWithState;
import org.eclipse.core.commands.IExecutionListenerWithChecks;
import org.eclipse.core.commands.ITypedParameter;
import org.eclipse.core.commands.HandlerEvent;

import java.lang.all;

/**
 * <p>
 * A command is an abstract representation for some semantic behaviour. It is
 * not the actual implementation of this behaviour, nor is it the visual
 * appearance of this behaviour in the user interface. Instead, it is a bridge
 * between the two.
 * </p>
 * <p>
 * The concept of a command is based on the command design pattern. The notable
 * difference is how the command delegates responsibility for execution. Rather
 * than allowing concrete subclasses, it uses a handler mechanism (see the
 * <code>handlers</code> extension point). This provides another level of
 * indirection.
 * </p>
 * <p>
 * A command will exist in two states: defined and undefined. A command is
 * defined if it is declared in the XML of a resolved plug-in. If the plug-in is
 * unloaded or the command is simply not declared, then it is undefined. Trying
 * to reference an undefined command will succeed, but trying to access any of
 * its functionality will fail with a <code>NotDefinedException</code>. If
 * you need to know when a command changes from defined to undefined (or vice
 * versa), then attach a command listener.
 * </p>
 * <p>
 * Commands are mutable and will change as their definition changes.
 * </p>
 *
 * @since 3.1
 */
public final class Command : NamedHandleObjectWithState,
        Comparable {

    /**
     * This flag can be set to <code>true</code> if commands should print
     * information to <code>System.out</code> when executing.
     */
    public static bool DEBUG_COMMAND_EXECUTION = false;

    /**
     * This flag can be set to <code>true</code> if commands should print
     * information to <code>System.out</code> when changing handlers.
     */
    public static bool DEBUG_HANDLERS = false;

    /**
     * This flag can be set to a particular command identifier if only that
     * command should print information to <code>System.out</code> when
     * changing handlers.
     */
    public static String DEBUG_HANDLERS_COMMAND_ID = null;

    /**
     * The category to which this command belongs. This value should not be
     * <code>null</code> unless the command is undefined.
     */
    private Category category = null;

    /**
     * A collection of objects listening to the execution of this command. This
     * collection is <code>null</code> if there are no listeners.
     */
    private /+transient+/ ListenerList executionListeners = null;

    /**
     * The handler currently associated with this command. This value may be
     * <code>null</code> if there is no handler currently.
     */
    private /+transient+/ IHandler handler = null;

    /**
     * The help context identifier for this command. This can be
     * <code>null</code> if there is no help currently associated with the
     * command.
     *
     * @since 3.2
     */
    private String helpContextId;

    /**
     * The ordered array of parameters understood by this command. This value
     * may be <code>null</code> if there are no parameters, or if the command
     * is undefined. It may also be empty.
     */
    private IParameter[] parameters = null;

    /**
     * The type of the return value of this command. This value may be
     * <code>null</code> if the command does not declare a return type.
     *
     * @since 3.2
     */
    private ParameterType returnType = null;

    /**
     * Our command will listen to the active handler for enablement changes so
     * that they can be fired from the command itself.
     *
     * @since 3.3
     */
    private IHandlerListener handlerListener;

    /**
     * Constructs a new instance of <code>Command</code> based on the given
     * identifier. When a command is first constructed, it is undefined.
     * Commands should only be constructed by the <code>CommandManager</code>
     * to ensure that the identifier remains unique.
     *
     * @param id
     *            The identifier for the command. This value must not be
     *            <code>null</code>, and must be unique amongst all commands.
     */
    this(String id) {
        super(id);
    }

    /**
     * Adds a listener to this command that will be notified when this command's
     * state changes.
     *
     * @param commandListener
     *            The listener to be added; must not be <code>null</code>.
     */
    public final void addCommandListener(ICommandListener commandListener) {
        if (commandListener is null) {
            throw new NullPointerException("Cannot add a null command listener"); //$NON-NLS-1$
        }
        addListenerObject(cast(Object)commandListener);
    }

    /**
     * Adds a listener to this command that will be notified when this command
     * is about to execute.
     *
     * @param executionListener
     *            The listener to be added; must not be <code>null</code>.
     */
    public final void addExecutionListener(
            IExecutionListener executionListener) {
        if (executionListener is null) {
            throw new NullPointerException(
                    "Cannot add a null execution listener"); //$NON-NLS-1$
        }

        if (executionListeners is null) {
            executionListeners = new ListenerList(ListenerList.IDENTITY);
        }

        executionListeners.add(cast(Object)executionListener);
    }

    /**
     * <p>
     * Adds a state to this command. This will add this state to the active
     * handler, if the active handler is an instance of {@link IObjectWithState}.
     * </p>
     * <p>
     * A single instance of {@link State} cannot be registered with multiple
     * commands. Each command requires its own unique instance.
     * </p>
     *
     * @param id
     *            The identifier of the state to add; must not be
     *            <code>null</code>.
     * @param state
     *            The state to add; must not be <code>null</code>.
     * @since 3.2
     */
    public override void addState(String id, State state) {
        super.addState(id, state);
        state.setId(id);
        if ( auto h = cast(IObjectWithState)handler) {
            h.addState(id, state);
        }
    }

    /**
     * Compares this command with another command by comparing each of its
     * non-transient attributes.
     *
     * @param object
     *            The object with which to compare; must be an instance of
     *            <code>Command</code>.
     * @return A negative integer, zero or a postivie integer, if the object is
     *         greater than, equal to or less than this command.
     */
    public final int compareTo(Object object) {
        Command castedObject = cast(Command) object;
        int compareTo = Util.compare(category, castedObject.category);
        if (compareTo is 0) {
            compareTo = Util.compare(defined, castedObject.defined);
            if (compareTo is 0) {
                compareTo = Util.compare(description, castedObject.description);
                if (compareTo is 0) {
                    compareTo = Util.compare(cast(Object)handler, cast(Object)castedObject.handler);
                    if (compareTo is 0) {
                        compareTo = Util.compare(id, castedObject.id);
                        if (compareTo is 0) {
                            compareTo = Util.compare(name, castedObject.name);
                            if (compareTo is 0) {
                                Object[] left, right;
                                foreach( p; parameters ){
                                    left ~= cast(Object)p;
                                }
                                foreach( p; castedObject.parameters ){
                                    right ~= cast(Object)p;
                                }
                                compareTo = Util.compare(left,
                                        right);
                            }
                        }
                    }
                }
            }
        }
        return compareTo;
    }
    public final override int opCmp( Object object ){
        return compareTo( object );
    }

    /**
     * <p>
     * Defines this command by giving it a name, and possibly a description as
     * well. The defined property automatically becomes <code>true</code>.
     * </p>
     * <p>
     * Notification is sent to all listeners that something has changed.
     * </p>
     *
     * @param name
     *            The name of this command; must not be <code>null</code>.
     * @param description
     *            The description for this command; may be <code>null</code>.
     * @param category
     *            The category for this command; must not be <code>null</code>.
     * @since 3.2
     */
    public final void define(String name, String description,
            Category category) {
        define(name, description, category, null);
    }

    /**
     * <p>
     * Defines this command by giving it a name, and possibly a description as
     * well. The defined property automatically becomes <code>true</code>.
     * </p>
     * <p>
     * Notification is sent to all listeners that something has changed.
     * </p>
     *
     * @param name
     *            The name of this command; must not be <code>null</code>.
     * @param description
     *            The description for this command; may be <code>null</code>.
     * @param category
     *            The category for this command; must not be <code>null</code>.
     * @param parameters
     *            The parameters understood by this command. This value may be
     *            either <code>null</code> or empty if the command does not
     *            accept parameters.
     */
    public final void define(String name, String description,
            Category category, IParameter[] parameters) {
        define(name, description, category, parameters, null);
    }

    /**
     * <p>
     * Defines this command by giving it a name, and possibly a description as
     * well. The defined property automatically becomes <code>true</code>.
     * </p>
     * <p>
     * Notification is sent to all listeners that something has changed.
     * </p>
     *
     * @param name
     *            The name of this command; must not be <code>null</code>.
     * @param description
     *            The description for this command; may be <code>null</code>.
     * @param category
     *            The category for this command; must not be <code>null</code>.
     * @param parameters
     *            The parameters understood by this command. This value may be
     *            either <code>null</code> or empty if the command does not
     *            accept parameters.
     * @param returnType
     *            The type of value returned by this command. This value may be
     *            <code>null</code> if the command does not declare a return
     *            type.
     * @since 3.2
     */
    public final void define(String name, String description,
            Category category, IParameter[] parameters,
            ParameterType returnType) {
        define(name, description, category, parameters, returnType, null);
    }

    /**
     * <p>
     * Defines this command by giving it a name, and possibly a description as
     * well. The defined property automatically becomes <code>true</code>.
     * </p>
     * <p>
     * Notification is sent to all listeners that something has changed.
     * </p>
     *
     * @param name
     *            The name of this command; must not be <code>null</code>.
     * @param description
     *            The description for this command; may be <code>null</code>.
     * @param category
     *            The category for this command; must not be <code>null</code>.
     * @param parameters
     *            The parameters understood by this command. This value may be
     *            either <code>null</code> or empty if the command does not
     *            accept parameters.
     * @param returnType
     *            The type of value returned by this command. This value may be
     *            <code>null</code> if the command does not declare a return
     *            type.
     * @param helpContextId
     *            The identifier of the help context to associate with this
     *            command; may be <code>null</code> if this command does not
     *            have any help associated with it.
     * @since 3.2
     */
    public final void define(String name, String description,
            Category category, IParameter[] parameters,
            ParameterType returnType, String helpContextId) {
        if (name is null) {
            throw new NullPointerException(
                    "The name of a command cannot be null"); //$NON-NLS-1$
        }

        if (category is null) {
            throw new NullPointerException(
                    "The category of a command cannot be null"); //$NON-NLS-1$
        }

        bool definedChanged = !this.defined;
        this.defined = true;

        bool nameChanged = !Util.equals(this.name, name);
        this.name = name;

        bool descriptionChanged = !Util.equals(this.description,
                description);
        this.description = description;

        bool categoryChanged = !Util.equals(this.category, category);
        this.category = category;

        Object[] pLeft, pRight;
        foreach( p; this.parameters ){
            pLeft ~= cast(Object)p;
        }
        foreach( p; parameters ){
            pRight ~= cast(Object)p;
        }
        bool parametersChanged = !Util.equals(pLeft,
                pRight);
        this.parameters = parameters;

        bool returnTypeChanged = !Util.equals(this.returnType,
                returnType);
        this.returnType = returnType;

        bool helpContextIdChanged = !Util.equals(this.helpContextId,
                helpContextId);
        this.helpContextId = helpContextId;

        fireCommandChanged(new CommandEvent(this, categoryChanged,
                definedChanged, descriptionChanged, false, nameChanged,
                parametersChanged, returnTypeChanged, helpContextIdChanged));
    }

    /**
     * Executes this command by delegating to the current handler, if any. If
     * the debugging flag is set, then this method prints information about
     * which handler is selected for performing this command. This method will
     * succeed regardless of whether the command is enabled or defined. It is
     * generally preferred to call {@link #executeWithChecks(ExecutionEvent)}.
     *
     * @param event
     *            An event containing all the information about the current
     *            state of the application; must not be <code>null</code>.
     * @return The result of the execution; may be <code>null</code>. This
     *         result will be available to the client executing the command, and
     *         execution listeners.
     * @throws ExecutionException
     *             If the handler has problems executing this command.
     * @throws NotHandledException
     *             If there is no handler.
     * @deprecated Please use {@link #executeWithChecks(ExecutionEvent)}
     *             instead.
     */
    public final Object execute(ExecutionEvent event) {
        firePreExecute(event);
        IHandler handler = this.handler;

        // Perform the execution, if there is a handler.
        if ((handler !is null) && (handler.isHandled())) {
            try {
                Object returnValue = handler.execute(event);
                firePostExecuteSuccess(returnValue);
                return returnValue;
            } catch (ExecutionException e) {
                firePostExecuteFailure(e);
                throw e;
            }
        }

        NotHandledException e = new NotHandledException(
                "There is no handler to execute. " ~ getId()); //$NON-NLS-1$
        fireNotHandled(e);
        throw e;
    }

    /**
     * Executes this command by delegating to the current handler, if any. If
     * the debugging flag is set, then this method prints information about
     * which handler is selected for performing this command. This does checks
     * to see if the command is enabled and defined. If it is not both enabled
     * and defined, then the execution listeners will be notified and an
     * exception thrown.
     *
     * @param event
     *            An event containing all the information about the current
     *            state of the application; must not be <code>null</code>.
     * @return The result of the execution; may be <code>null</code>. This
     *         result will be available to the client executing the command, and
     *         execution listeners.
     * @throws ExecutionException
     *             If the handler has problems executing this command.
     * @throws NotDefinedException
     *             If the command you are trying to execute is not defined.
     * @throws NotEnabledException
     *             If the command you are trying to execute is not enabled.
     * @throws NotHandledException
     *             If there is no handler.
     * @since 3.2
     */
    public final Object executeWithChecks(ExecutionEvent event) {
        firePreExecute(event);
        IHandler handler = this.handler;

        if (!isDefined()) {
            NotDefinedException exception = new NotDefinedException(
                    "Trying to execute a command that is not defined. " //$NON-NLS-1$
                            ~ getId());
            fireNotDefined(exception);
            throw exception;
        }

        // Perform the execution, if there is a handler.
        if ((handler !is null) && (handler.isHandled())) {
            setEnabled(event.getApplicationContext());
            if (!isEnabled()) {
                NotEnabledException exception = new NotEnabledException(
                        "Trying to execute the disabled command " ~ getId()); //$NON-NLS-1$
                fireNotEnabled(exception);
                throw exception;
            }

            try {
                Object returnValue = handler.execute(event);
                firePostExecuteSuccess(returnValue);
                return returnValue;
            } catch (ExecutionException e) {
                firePostExecuteFailure(e);
                throw e;
            }
        }

        NotHandledException e = new NotHandledException(
                "There is no handler to execute for command " ~ getId()); //$NON-NLS-1$
        fireNotHandled(e);
        throw e;
    }

    /**
     * Notifies the listeners for this command that it has changed in some way.
     *
     * @param commandEvent
     *            The event to send to all of the listener; must not be
     *            <code>null</code>.
     */
    private final void fireCommandChanged(CommandEvent commandEvent) {
        if (commandEvent is null) {
            throw new NullPointerException("Cannot fire a null event"); //$NON-NLS-1$
        }

        Object[] listeners = getListeners();
        for (int i = 0; i < listeners.length; i++) {
            ICommandListener listener = cast(ICommandListener) listeners[i];
            SafeRunner.run(new class(listener) ISafeRunnable {
                ICommandListener listener_;
                this(ICommandListener a){ this.listener_ = a; }
                public void handleException(Exception exception) {
                }

                public void run() {
                    listener_.commandChanged(commandEvent);
                }
            });
        }
    }

    /**
     * Notifies the execution listeners for this command that an attempt to
     * execute has failed because the command is not defined.
     *
     * @param e
     *            The exception that is about to be thrown; never
     *            <code>null</code>.
     * @since 3.2
     */
    private final void fireNotDefined(NotDefinedException e) {
        // Debugging output
        if (DEBUG_COMMAND_EXECUTION) {
            Tracing.printTrace("COMMANDS", "execute" ~ Tracing.SEPARATOR //$NON-NLS-1$ //$NON-NLS-2$
                    ~ "not defined: id=" ~ getId() ~ "; exception=" ~ e.toString ); //$NON-NLS-1$ //$NON-NLS-2$
        }

        if (executionListeners !is null) {
            Object[] listeners = executionListeners.getListeners();
            for (int i = 0; i < listeners.length; i++) {
                Object object = listeners[i];
                if ( auto listener = cast(IExecutionListenerWithChecks)object ) {
                    listener.notDefined(getId(), e);
                }
            }
        }
    }

    /**
     * Notifies the execution listeners for this command that an attempt to
     * execute has failed because there is no handler.
     *
     * @param e
     *            The exception that is about to be thrown; never
     *            <code>null</code>.
     * @since 3.2
     */
    private final void fireNotEnabled(NotEnabledException e) {
        // Debugging output
        if (DEBUG_COMMAND_EXECUTION) {
            Tracing.printTrace("COMMANDS", "execute" ~ Tracing.SEPARATOR //$NON-NLS-1$ //$NON-NLS-2$
                    ~ "not enabled: id=" ~ getId() ~ "; exception=" ~ e.toString ); //$NON-NLS-1$ //$NON-NLS-2$
        }

        if (executionListeners !is null) {
            Object[] listeners = executionListeners.getListeners();
            for (int i = 0; i < listeners.length; i++) {
                Object object = listeners[i];
                if ( auto listener = cast(IExecutionListenerWithChecks)object ) {
                    listener.notEnabled(getId(), e);
                }
            }
        }
    }

    /**
     * Notifies the execution listeners for this command that an attempt to
     * execute has failed because there is no handler.
     *
     * @param e
     *            The exception that is about to be thrown; never
     *            <code>null</code>.
     */
    private final void fireNotHandled(NotHandledException e) {
        // Debugging output
        if (DEBUG_COMMAND_EXECUTION) {
            Tracing.printTrace("COMMANDS", "execute" ~ Tracing.SEPARATOR //$NON-NLS-1$ //$NON-NLS-2$
                    ~ "not handled: id=" ~ getId() ~ "; exception=" ~ e.toString ); //$NON-NLS-1$ //$NON-NLS-2$
        }

        if (executionListeners !is null) {
            Object[] listeners = executionListeners.getListeners();
            for (int i = 0; i < listeners.length; i++) {
                IExecutionListener listener = cast(IExecutionListener) listeners[i];
                listener.notHandled(getId(), e);
            }
        }
    }

    /**
     * Notifies the execution listeners for this command that an attempt to
     * execute has failed during the execution.
     *
     * @param e
     *            The exception that has been thrown; never <code>null</code>.
     *            After this method completes, the exception will be thrown
     *            again.
     */
    private final void firePostExecuteFailure(ExecutionException e) {
        // Debugging output
        if (DEBUG_COMMAND_EXECUTION) {
            Tracing.printTrace("COMMANDS", "execute" ~ Tracing.SEPARATOR //$NON-NLS-1$ //$NON-NLS-2$
                    ~ "failure: id=" ~ getId() ~ "; exception=" ~ e.toString ); //$NON-NLS-1$ //$NON-NLS-2$
        }

        if (executionListeners !is null) {
            Object[] listeners = executionListeners.getListeners();
            for (int i = 0; i < listeners.length; i++) {
                IExecutionListener listener = cast(IExecutionListener) listeners[i];
                listener.postExecuteFailure(getId(), e);
            }
        }
    }

    /**
     * Notifies the execution listeners for this command that an execution has
     * completed successfully.
     *
     * @param returnValue
     *            The return value from the command; may be <code>null</code>.
     */
    private final void firePostExecuteSuccess(Object returnValue) {
        // Debugging output
        if (DEBUG_COMMAND_EXECUTION) {
            Tracing.printTrace("COMMANDS", "execute" ~ Tracing.SEPARATOR //$NON-NLS-1$ //$NON-NLS-2$
                    ~ "success: id=" ~ getId() ~ "; returnValue=" //$NON-NLS-1$ //$NON-NLS-2$
                    ~ returnValue.toString );
        }

        if (executionListeners !is null) {
            Object[] listeners = executionListeners.getListeners();
            for (int i = 0; i < listeners.length; i++) {
                IExecutionListener listener = cast(IExecutionListener) listeners[i];
                listener.postExecuteSuccess(getId(), returnValue);
            }
        }
    }

    /**
     * Notifies the execution listeners for this command that an attempt to
     * execute is about to start.
     *
     * @param event
     *            The execution event that will be used; never <code>null</code>.
     */
    private final void firePreExecute(ExecutionEvent event) {
        // Debugging output
        if (DEBUG_COMMAND_EXECUTION) {
            Tracing.printTrace("COMMANDS", "execute" ~ Tracing.SEPARATOR //$NON-NLS-1$ //$NON-NLS-2$
                    ~ "starting: id=" ~ getId() ~ "; event=" ~ event.toString ); //$NON-NLS-1$ //$NON-NLS-2$
        }

        if (executionListeners !is null) {
            Object[] listeners = executionListeners.getListeners();
            for (int i = 0; i < listeners.length; i++) {
                IExecutionListener listener = cast(IExecutionListener) listeners[i];
                listener.preExecute(getId(), event);
            }
        }
    }

    /**
     * Returns the category for this command.
     *
     * @return The category for this command; never <code>null</code>.
     * @throws NotDefinedException
     *             If the handle is not currently defined.
     */
    public final Category getCategory() {
        if (!isDefined()) {
            throw new NotDefinedException(
                    "Cannot get the category from an undefined command. " //$NON-NLS-1$
                            ~ id);
        }

        return category;
    }

    /**
     * Returns the current handler for this command. This is used by the command
     * manager for determining the appropriate help context identifiers and by
     * the command service to allow handlers to update elements.
     * <p>
     * This value can change at any time and should never be cached.
     * </p>
     *
     * @return The current handler for this command; may be <code>null</code>.
     * @since 3.3
     */
    public final IHandler getHandler() {
        return handler;
    }

    /**
     * Returns the help context identifier associated with this command. This
     * method should not be called by clients. Clients should use
     * {@link CommandManager#getHelpContextId(Command)} instead.
     *
     * @return The help context identifier for this command; may be
     *         <code>null</code> if there is none.
     * @since 3.2
     */
    final String getHelpContextId() {
        return helpContextId;
    }

    /**
     * Returns the parameter with the provided id or <code>null</code> if this
     * command does not have a parameter with the id.
     *
     * @param parameterId
     *            The id of the parameter to retrieve.
     * @return The parameter with the provided id or <code>null</code> if this
     *         command does not have a parameter with the id.
     * @throws NotDefinedException
     *             If the handle is not currently defined.
     * @since 3.2
     */
    public final IParameter getParameter(String parameterId) {
        if (!isDefined()) {
            throw new NotDefinedException(
                    "Cannot get a parameter from an undefined command. " //$NON-NLS-1$
                            ~ id);
        }

        if (parameters is null) {
            return null;
        }

        for (int i = 0; i < parameters.length; i++) {
            IParameter parameter = parameters[i];
            if (parameter.getId().equals(parameterId)) {
                return parameter;
            }
        }

        return null;
    }

    /**
     * Returns the parameters for this command. This call triggers provides a
     * copy of the array, so excessive calls to this method should be avoided.
     *
     * @return The parameters for this command. This value might be
     *         <code>null</code>, if the command has no parameters.
     * @throws NotDefinedException
     *             If the handle is not currently defined.
     */
    public final IParameter[] getParameters() {
        if (!isDefined()) {
            throw new NotDefinedException(
                    "Cannot get the parameters from an undefined command. " //$NON-NLS-1$
                            ~ id);
        }

        if ((parameters is null) || (parameters.length is 0)) {
            return null;
        }

        IParameter[] returnValue = new IParameter[parameters.length];
        SimpleType!(IParameter).arraycopy(parameters, 0, returnValue, 0, parameters.length);
        return returnValue;
    }

    /**
     * Returns the {@link ParameterType} for the parameter with the provided id
     * or <code>null</code> if this command does not have a parameter type
     * with the id.
     *
     * @param parameterId
     *            The id of the parameter to retrieve the {@link ParameterType}
     *            of.
     * @return The {@link ParameterType} for the parameter with the provided id
     *         or <code>null</code> if this command does not have a parameter
     *         type with the provided id.
     * @throws NotDefinedException
     *             If the handle is not currently defined.
     * @since 3.2
     */
    public final ParameterType getParameterType(String parameterId) {
        IParameter parameter = getParameter(parameterId);
        if ( auto parameterWithType = cast(ITypedParameter)parameter ) {
            return parameterWithType.getParameterType();
        }
        return null;
    }

    /**
     * Returns the {@link ParameterType} for the return value of this command or
     * <code>null</code> if this command does not declare a return value
     * parameter type.
     *
     * @return The {@link ParameterType} for the return value of this command or
     *         <code>null</code> if this command does not declare a return
     *         value parameter type.
     * @throws NotDefinedException
     *             If the handle is not currently defined.
     * @since 3.2
     */
    public final ParameterType getReturnType() {
        if (!isDefined()) {
            throw new NotDefinedException(
                    "Cannot get the return type of an undefined command. " //$NON-NLS-1$
                            ~ id);
        }

        return returnType;
    }

    /**
     * Returns whether this command has a handler, and whether this handler is
     * also handled and enabled.
     *
     * @return <code>true</code> if the command is handled; <code>false</code>
     *         otherwise.
     */
    public final bool isEnabled() {
        if (handler is null) {
            return false;
        }

        try {
            return handler.isEnabled();
        } catch (Exception e) {
            if (DEBUG_HANDLERS) {
                // since this has the ability to generate megs of logs, only
                // provide information if tracing
                Tracing.printTrace("HANDLERS", "Handler " ~ (cast(Object)handler).toString()  ~ " for "  //$NON-NLS-1$//$NON-NLS-2$ //$NON-NLS-3$
                        ~ id ~ " threw unexpected exception"); //$NON-NLS-1$
                ExceptionPrintStackTrace( e, & getDwtLogger().info );
            }
        }
        return false;
    }

    /**
     * Called be the framework to allow the handler to update its enabled state.
     *
     * @param evaluationContext
     *            the state to evaluate against. May be <code>null</code>
     *            which indicates that the handler can query whatever model that
     *            is necessary.  This context must not be cached.
     * @since 3.4
     */
    public void setEnabled(Object evaluationContext) {
        if (null !is cast(IHandler2)handler ) {
            (cast(IHandler2) handler).setEnabled(evaluationContext);
        }
    }

    /**
     * Returns whether this command has a handler, and whether this handler is
     * also handled.
     *
     * @return <code>true</code> if the command is handled; <code>false</code>
     *         otherwise.
     */
    public final bool isHandled() {
        if (handler is null) {
            return false;
        }

        return handler.isHandled();
    }

    /**
     * Removes a listener from this command.
     *
     * @param commandListener
     *            The listener to be removed; must not be <code>null</code>.
     *
     */
    public final void removeCommandListener(
            ICommandListener commandListener) {
        if (commandListener is null) {
            throw new NullPointerException(
                    "Cannot remove a null command listener"); //$NON-NLS-1$
        }

        removeListenerObject(cast(Object)commandListener);
    }

    /**
     * Removes a listener from this command.
     *
     * @param executionListener
     *            The listener to be removed; must not be <code>null</code>.
     *
     */
    public final void removeExecutionListener(
            IExecutionListener executionListener) {
        if (executionListener is null) {
            throw new NullPointerException(
                    "Cannot remove a null execution listener"); //$NON-NLS-1$
        }

        if (executionListeners !is null) {
            executionListeners.remove(cast(Object)executionListener);
            if (executionListeners.isEmpty()) {
                executionListeners = null;
            }
        }
    }

    /**
     * <p>
     * Removes a state from this command. This will remove the state from the
     * active handler, if the active handler is an instance of
     * {@link IObjectWithState}.
     * </p>
     *
     * @param stateId
     *            The identifier of the state to remove; must not be
     *            <code>null</code>.
     * @since 3.2
     */
    public override void removeState(String stateId) {
        if ( auto h = cast(IObjectWithState)handler ) {
            h.removeState(stateId);
        }
        super.removeState(stateId);
    }

    /**
     * Changes the handler for this command. This will remove all the state from
     * the currently active handler (if any), and add it to <code>handler</code>.
     * If debugging is turned on, then this will also print information about
     * the change to <code>System.out</code>.
     *
     * @param handler
     *            The new handler; may be <code>null</code> if none.
     * @return <code>true</code> if the handler changed; <code>false</code>
     *         otherwise.
     */
    public final bool setHandler(IHandler handler) {
        if (Util.equals(cast(Object)handler, cast(Object)this.handler)) {
            return false;
        }

        // Swap the state around.
        String[] stateIds = getStateIds();
        if (stateIds !is null) {
            for (int i = 0; i < stateIds.length; i++) {
                String stateId = stateIds[i];
                if ( auto h = cast(IObjectWithState)this.handler ) {
                    h.removeState(stateId);
                }
                if ( auto h = cast(IObjectWithState)handler ) {
                    State stateToAdd = getState(stateId);
                    h.addState(stateId, stateToAdd);
                }
            }
        }

        bool enabled = isEnabled();
        if (this.handler !is null) {
            this.handler.removeHandlerListener(getHandlerListener());
        }

        // Update the handler, and flush the string representation.
        this.handler = handler;
        if (this.handler !is null) {
            this.handler.addHandlerListener(getHandlerListener());
        }
        string = null;

        // Debugging output
        if ((DEBUG_HANDLERS)
                && ((DEBUG_HANDLERS_COMMAND_ID is null) || (DEBUG_HANDLERS_COMMAND_ID
                        .equals(id)))) {
            StringBuffer buffer = new StringBuffer("Command('"); //$NON-NLS-1$
            buffer.append(id);
            buffer.append("') has changed to "); //$NON-NLS-1$
            if (handler is null) {
                buffer.append("no handler"); //$NON-NLS-1$
            } else {
                buffer.append('\'');
                buffer.append(( cast(Object)handler).toString);
                buffer.append("' as its handler"); //$NON-NLS-1$
            }
            Tracing.printTrace("HANDLERS", buffer.toString()); //$NON-NLS-1$
        }

        // Send notification
        fireCommandChanged(new CommandEvent(this, false, false, false, true,
                false, false, false, false, enabled !is isEnabled()));

        return true;
    }

    /**
     * @return the handler listener
     */
    private IHandlerListener getHandlerListener() {
        if (handlerListener is null) {
            handlerListener = new class IHandlerListener {
                public void handlerChanged(HandlerEvent handlerEvent) {
                    bool enabledChanged = handlerEvent.isEnabledChanged();
                    bool handledChanged = handlerEvent.isHandledChanged();
                    fireCommandChanged(new CommandEvent(this.outer, false,
                            false, false, handledChanged, false, false, false,
                            false, enabledChanged));
                }
            };
        }
        return handlerListener;
    }

    /**
     * The string representation of this command -- for debugging purposes only.
     * This string should not be shown to an end user.
     *
     * @return The string representation; never <code>null</code>.
     */
    public override final String toString() {
        if (string is null) {
            String parms;
            foreach( p; parameters ){
                parms ~= "{"~(cast(Object)p).toString~"}";
            }
            string = Format("Command({},{},\n\t\t{},\n\t\t{},\n\t\t{},\n\t\t{},{},{})",
                id,
                name is null ? "":name,
                description is null?"":description,
                category is null?"":category.toString(),
                handler is null?"": (cast(Object)handler).toString(),
                parms,
                returnType is null?"":returnType.toString(),
                defined
            );
        }
        return string;
    }

    /**
     * Makes this command become undefined. This has the side effect of changing
     * the name and description to <code>null</code>. This also removes all
     * state and disposes of it. Notification is sent to all listeners.
     */
    public override final void undefine() {
        bool enabledChanged = isEnabled();

        string = null;

        bool definedChanged = defined;
        defined = false;

        bool nameChanged = name !is null;
        name = null;

        bool descriptionChanged = description !is null;
        description = null;

        bool categoryChanged = category !is null;
        category = null;

        bool parametersChanged = parameters !is null;
        parameters = null;

        bool returnTypeChanged = returnType !is null;
        returnType = null;

        String[] stateIds = getStateIds();
        if (stateIds !is null) {
            if ( auto handlerWithState = cast(IObjectWithState)handler ) {
                for (int i = 0; i < stateIds.length; i++) {
                    String stateId = stateIds[i];
                    handlerWithState.removeState(stateId);

                    State state = getState(stateId);
                    removeState(stateId);
                    state.dispose();
                }
            } else {
                for (int i = 0; i < stateIds.length; i++) {
                    String stateId = stateIds[i];
                    State state = getState(stateId);
                    removeState(stateId);
                    state.dispose();
                }
            }
        }

        fireCommandChanged(new CommandEvent(this, categoryChanged,
                definedChanged, descriptionChanged, false, nameChanged,
                parametersChanged, returnTypeChanged, false, enabledChanged));
    }
}
