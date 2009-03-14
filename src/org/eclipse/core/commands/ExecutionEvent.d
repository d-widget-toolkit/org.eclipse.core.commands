/*******************************************************************************
 * Copyright (c) 2005, 2007 IBM Corporation and others.
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
module org.eclipse.core.commands.ExecutionEvent;

// import java.util.Collections;

import org.eclipse.core.commands.common.NotDefinedException;
import org.eclipse.core.commands.ExecutionException;
import org.eclipse.core.commands.Command;
import org.eclipse.core.commands.ParameterType;
import org.eclipse.core.commands.AbstractParameterValueConverter;
import org.eclipse.core.commands.ParameterValueConversionException;

import java.lang.all;
import java.util.Map;
import java.util.Collections;

/**
 * <p>
 * The data object to pass to the command (and its handler) as it executes. This
 * carries information about the current state of the application, and the
 * application context in which the command was executed.
 * </p>
 * <p>
 * An execution event carries three blocks of data: the parameters, the trigger,
 * and the application context. How these blocks are used is application
 * dependent. In the Eclipse workbench, the trigger is an SWT event, and the
 * application context contains information about the selection and active part.
 * </p>
 *
 * @since 3.1
 */
public final class ExecutionEvent {
    /**
     * The state of the application at the time the execution was triggered. In
     * the Eclipse workbench, this might contain information about the active
     * part of the active selection (for example). This value may be
     * <code>null</code>.
     */
    private const Object applicationContext;

    /**
     * The command being executed. This value may be <code>null</code>.
     */
    private const Command command;

    /**
     * The parameters to qualify the execution. For handlers that normally
     * prompt for additional information, these can be used to avoid prompting.
     * This value may be empty, but it is never <code>null</code>.
     */
    private const Map parameters;

    /**
     * The object that triggered the execution. In an event-driven architecture,
     * this is typically just another event. In the Eclipse workbench, this is
     * typically an SWT event. This value may be <code>null</code>.
     */
    private const Object trigger;

    /**
     * Constructs a new instance of <code>ExecutionEvent</code> with no
     * parameters, no trigger and no application context. This is just a
     * convenience method.
     *
     * @since 3.2
     */
    public this() {
        this(null, Collections.EMPTY_MAP, null, null);
    }

    /**
     * Constructs a new instance of <code>ExecutionEvent</code>.
     *
     * @param parameters
     *            The parameters to qualify the execution; must not be
     *            <code>null</code>. This must be a map of parameter ids (<code>String</code>)
     *            to parameter values (<code>String</code>).
     * @param trigger
     *            The object that triggered the execution; may be
     *            <code>null</code>.
     * @param applicationContext
     *            The state of the application at the time the execution was
     *            triggered; may be <code>null</code>.
     * @deprecated use
     *             {@link ExecutionEvent#ExecutionEvent(Command, Map, Object, Object)}
     */
    public this(Map parameters, Object trigger,
            Object applicationContext) {
        this(null, parameters, trigger, applicationContext);
    }

    /**
     * Constructs a new instance of <code>ExecutionEvent</code>.
     *
     * @param command
     *            The command being executed; may be <code>null</code>.
     * @param parameters
     *            The parameters to qualify the execution; must not be
     *            <code>null</code>. This must be a map of parameter ids (<code>String</code>)
     *            to parameter values (<code>String</code>).
     * @param trigger
     *            The object that triggered the execution; may be
     *            <code>null</code>.
     * @param applicationContext
     *            The state of the application at the time the execution was
     *            triggered; may be <code>null</code>.
     * @since 3.2
     */
    public this(Command command, Map parameters,
            Object trigger, Object applicationContext) {
        if (parameters is null) {
            throw new NullPointerException(
                    "An execution event must have a non-null map of parameters"); //$NON-NLS-1$
        }

        this.command = command;
        this.parameters = parameters;
        this.trigger = trigger;
        this.applicationContext = applicationContext;
    }

    /**
     * Returns the state of the application at the time the execution was
     * triggered.
     *
     * @return The application context; may be <code>null</code>.
     */
    public final Object getApplicationContext() {
        return applicationContext;
    }

    /**
     * Returns the command being executed.
     *
     * @return The command being executed.
     * @since 3.2
     */
    public final Command getCommand() {
        return command;
    }

    /**
     * Returns the object represented by the string value of the parameter with
     * the provided id.
     * <p>
     * This is intended to be used in the scope of an
     * {@link IHandler#execute(ExecutionEvent)} method, so any problem getting
     * the object value causes <code>ExecutionException</code> to be thrown.
     * </p>
     *
     * @param parameterId
     *            The id of a parameter to retrieve the object value of.
     * @return The object value of the parameter with the provided id.
     * @throws ExecutionException
     *             if the parameter object value could not be obtained for any
     *             reason
     * @since 3.2
     */
    public final Object getObjectParameterForExecution(String parameterId) {
        if (command is null) {
            throw new ExecutionException(
                    "No command is associated with this execution event"); //$NON-NLS-1$
        }

        try {
            ParameterType parameterType = command
                    .getParameterType(parameterId);
            if (parameterType is null) {
                throw new ExecutionException(
                        "Command does not have a parameter type for the given parameter"); //$NON-NLS-1$
            }
            AbstractParameterValueConverter valueConverter = parameterType
                    .getValueConverter();
            if (valueConverter is null) {
                throw new ExecutionException(
                        "Command does not have a value converter"); //$NON-NLS-1$
            }
            String stringValue = getParameter(parameterId);
            Object objectValue = valueConverter
                    .convertToObject(stringValue);
            return objectValue;
        } catch (NotDefinedException e) {
            throw new ExecutionException("Command is not defined", e); //$NON-NLS-1$
        } catch (ParameterValueConversionException e) {
            throw new ExecutionException(
                    "The parameter string could not be converted to an object", e); //$NON-NLS-1$
        }
    }

    /**
     * Returns the value of the parameter with the given id.
     *
     * @param parameterId
     *            The id of the parameter to retrieve; may be <code>null</code>.
     * @return The parameter value; <code>null</code> if the parameter cannot
     *         be found.
     */
    public final String getParameter(String parameterId) {
        return stringcast(parameters.get(parameterId));
    }

    /**
     * Returns all of the parameters.
     *
     * @return The parameters; never <code>null</code>, but may be empty.
     */
    public final Map getParameters() {
        return parameters;
    }

    /**
     * Returns the object that triggered the execution
     *
     * @return The trigger; <code>null</code> if there was no trigger.
     */
    public final Object getTrigger() {
        return trigger;
    }

    /**
     * The string representation of this execution event -- for debugging
     * purposes only. This string should not be shown to an end user.
     *
     * @return The string representation; never <code>null</code>.
     */
    public override final String toString() {
        String parm;
        foreach( k, v; parameters ){
            parm ~= "{"~stringcast(k)~","~stringcast(v)~"}";
        }
        return Format( "ExecutionEvent({},{},{})", command, parm, trigger, applicationContext );
    }
}
