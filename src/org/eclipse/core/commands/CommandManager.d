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
module org.eclipse.core.commands.CommandManager;

import org.eclipse.core.commands.common.HandleObjectManager;
import org.eclipse.core.commands.common.NotDefinedException;
import org.eclipse.core.runtime.ListenerList;

import org.eclipse.core.commands.ICategoryListener;
import org.eclipse.core.commands.ICommandListener;
import org.eclipse.core.commands.IExecutionListener;
import org.eclipse.core.commands.IExecutionListenerWithChecks;
import org.eclipse.core.commands.IParameterTypeListener;
import org.eclipse.core.commands.ICommandManagerListener;
import org.eclipse.core.commands.CommandEvent;
import org.eclipse.core.commands.CommandManagerEvent;
import org.eclipse.core.commands.Command;
import org.eclipse.core.commands.Category;
import org.eclipse.core.commands.CategoryEvent;
import org.eclipse.core.commands.IHandler;
import org.eclipse.core.commands.ParameterType;
import org.eclipse.core.commands.IParameter;
import org.eclipse.core.commands.Parameterization;
import org.eclipse.core.commands.ParameterizedCommand;
import org.eclipse.core.commands.ParameterTypeEvent;
import org.eclipse.core.commands.SerializationException;

import org.eclipse.core.commands.NotEnabledException;
import org.eclipse.core.commands.NotHandledException;
import org.eclipse.core.commands.ExecutionException;
import org.eclipse.core.commands.ExecutionEvent;

import java.lang.all;

import java.util.WeakHashMap;
import java.util.HashMap;
import java.util.Map;
import java.util.Iterator;
import java.util.Collections;
import java.util.ArrayList;
import java.util.Set;
import java.util.HashSet;

/**
 * <p>
 * A central repository for commands -- both in the defined and undefined
 * states. Commands can be created and retrieved using this manager. It is
 * possible to listen to changes in the collection of commands by attaching a
 * listener to the manager.
 * </p>
 *
 * @see CommandManager#getCommand(String)
 * @since 3.1
 */
public final class CommandManager : HandleObjectManager,
        ICategoryListener, ICommandListener, IParameterTypeListener {

    /**
     * A listener that forwards incoming execution events to execution listeners
     * on this manager. The execution events will come from any command on this
     * manager.
     *
     * @since 3.1
     */
    private final class ExecutionListener :
            IExecutionListenerWithChecks {

        public void notDefined(String commandId, NotDefinedException exception) {
            if (executionListeners !is null) {
                Object[] listeners = executionListeners.getListeners();
                for (int i = 0; i < listeners.length; i++) {
                    Object object = listeners[i];
                    if ( auto listener = cast(IExecutionListenerWithChecks)object ) {
                        listener.notDefined(commandId, exception);
                    }
                }
            }
        }

        public void notEnabled(String commandId, NotEnabledException exception) {
            if (executionListeners !is null) {
                Object[] listeners = executionListeners.getListeners();
                for (int i = 0; i < listeners.length; i++) {
                    Object object = listeners[i];
                    if ( auto listener = cast(IExecutionListenerWithChecks)object ) {
                        listener.notEnabled(commandId, exception);
                    }
                }
            }
        }

        public final void notHandled(String commandId,
                NotHandledException exception) {
            if (executionListeners !is null) {
                Object[] listeners = executionListeners.getListeners();
                for (int i = 0; i < listeners.length; i++) {
                    Object object = listeners[i];
                    if ( auto listener = cast(IExecutionListener)object ) {
                        listener.notHandled(commandId, exception);
                    }
                }
            }
        }

        public final void postExecuteFailure(String commandId,
                ExecutionException exception) {
            if (executionListeners !is null) {
                Object[] listeners = executionListeners.getListeners();
                for (int i = 0; i < listeners.length; i++) {
                    Object object = listeners[i];
                    if ( auto listener = cast(IExecutionListener)object ) {
                        listener.postExecuteFailure(commandId, exception);
                    }
                }
            }
        }

        public final void postExecuteSuccess(String commandId,
                Object returnValue) {
            if (executionListeners !is null) {
                Object[] listeners = executionListeners.getListeners();
                for (int i = 0; i < listeners.length; i++) {
                    Object object = listeners[i];
                    if ( auto listener = cast(IExecutionListener)object ) {
                        listener.postExecuteSuccess(commandId, returnValue);
                    }
                }
            }
        }

        public final void preExecute(String commandId,
                ExecutionEvent event) {
            if (executionListeners !is null) {
                Object[] listeners = executionListeners.getListeners();
                for (int i = 0; i < listeners.length; i++) {
                    Object object = listeners[i];
                    if ( auto listener = cast(IExecutionListener)object ) {
                        listener.preExecute(commandId, event);
                    }
                }
            }
        }
    }

    /**
     * The identifier of the category in which all auto-generated commands will
     * appear. This value must never be <code>null</code>.
     *
     * @since 3.2
     */
    public static const String AUTOGENERATED_CATEGORY_ID = "org.eclipse.core.commands.categories.autogenerated"; //$NON-NLS-1$

    /**
     * The escape character to use for serialization and deserialization of
     * parameterized commands.
     */
    static const char ESCAPE_CHAR = '%';

    /**
     * The character that separates a parameter id from its value.
     */
    static const char ID_VALUE_CHAR = '=';

    /**
     * The character that indicates the end of a list of parameters.
     */
    static const char PARAMETER_END_CHAR = ')';

    /**
     * The character that separators parameters from each other.
     */
    static const char PARAMETER_SEPARATOR_CHAR = ',';

    /**
     * The character that indicates the start of a list of parameters.
     */
    static const char PARAMETER_START_CHAR = '(';

    this(){
        categoriesById = new HashMap();
        definedCategoryIds = new HashSet();
        definedParameterTypeIds = new HashSet();
        helpContextIdsByHandler = new WeakHashMap();
        parameterTypesById = new HashMap();
    }

    /**
     * Unescapes special characters in the command id, parameter ids and
     * parameter values for {@link #deserialize(String)}. The special characters
     * {@link #PARAMETER_START_CHAR}, {@link #PARAMETER_END_CHAR},
     * {@link #ID_VALUE_CHAR}, {@link #PARAMETER_SEPARATOR_CHAR} and
     * {@link #ESCAPE_CHAR} are escaped by prepending an {@link #ESCAPE_CHAR}
     * character.
     * <p>
     * See also ParameterizedCommand.escape(String)
     * </p>
     *
     * @param escapedText
     *            a <code>String</code> that may contain escaped special
     *            characters for command serialization.
     * @return a <code>String</code> representing <code>escapedText</code>
     *         with any escaped characters replaced by their literal values
     * @throws SerializationException
     *             if <code>escapedText</code> contains an invalid escape
     *             sequence
     * @since 3.2
     */
    private static final String unescape(String escapedText) {

        // defer initialization of a StringBuffer until we know we need one
        StringBuffer buffer;

        for (int i = 0; i < escapedText.length; i++) {

            char c = escapedText.charAt(i);
            if (c !is ESCAPE_CHAR) {
                // normal unescaped character
                if (buffer !is null) {
                    buffer.append(c);
                }
            } else {
                if (buffer is null) {
                    buffer = new StringBuffer(escapedText.substring(0, i));
                }

                if (++i < escapedText.length) {
                    c = escapedText.charAt(i);
                    switch (c) {
                    case PARAMETER_START_CHAR:
                    case PARAMETER_END_CHAR:
                    case ID_VALUE_CHAR:
                    case PARAMETER_SEPARATOR_CHAR:
                    case ESCAPE_CHAR:
                        buffer.append(c);
                        break;
                    default:
                        throw new SerializationException(
                                "Invalid character '" ~ c ~ "' in escape sequence"); //$NON-NLS-1$ //$NON-NLS-2$
                    }
                } else {
                    throw new SerializationException(
                            "Unexpected termination of escape sequence"); //$NON-NLS-1$
                }
            }

        }

        if (buffer is null) {
            return escapedText;
        }

        return buffer.toString();
    }

    /**
     * The map of category identifiers (<code>String</code>) to categories (
     * <code>Category</code>). This collection may be empty, but it is never
     * <code>null</code>.
     */
    private const Map categoriesById;

    /**
     * The set of identifiers for those categories that are defined. This value
     * may be empty, but it is never <code>null</code>.
     */
    private const Set definedCategoryIds;

    /**
     * The set of identifiers for those command parameter types that are
     * defined. This value may be empty, but it is never <code>null</code>.
     *
     * @since 3.2
     */
    private const Set definedParameterTypeIds;

    /**
     * The execution listener for this command manager. This just forwards
     * events from commands controlled by this manager to listeners on this
     * manager.
     */
    private IExecutionListenerWithChecks executionListener = null;

    /**
     * The collection of execution listeners. This collection is
     * <code>null</code> if there are no listeners.
     */
    private ListenerList executionListeners = null;

    /**
     * The help context identifiers ({@link String}) for a handler ({@link IHandler}).
     * This map may be empty, but it is never <code>null</code>. Entries are
     * removed if all strong references to the handler are removed.
     *
     * @since 3.2
     */
    private const WeakHashMap helpContextIdsByHandler;

    /**
     * The map of parameter type identifiers (<code>String</code>) to
     * parameter types ( <code>ParameterType</code>). This collection may be
     * empty, but it is never <code>null</code>.
     *
     * @since 3.2
     */
    private const Map parameterTypesById;

    /**
     * Adds a listener to this command manager. The listener will be notified
     * when the set of defined commands changes. This can be used to track the
     * global appearance and disappearance of commands.
     *
     * @param listener
     *            The listener to attach; must not be <code>null</code>.
     */
    public final void addCommandManagerListener(
            ICommandManagerListener listener) {
        addListenerObject(cast(Object)listener);
    }

    /**
     * Adds an execution listener to this manager. This listener will be
     * notified if any of the commands controlled by this manager execute. This
     * can be used to support macros and instrumentation of commands.
     *
     * @param listener
     *            The listener to attach; must not be <code>null</code>.
     */
    public final void addExecutionListener(IExecutionListener listener) {
        if (listener is null) {
            throw new NullPointerException(
                    "Cannot add a null execution listener"); //$NON-NLS-1$
        }

        if (executionListeners is null) {
            executionListeners = new ListenerList(ListenerList.IDENTITY);

            // Add an execution listener to every command.
            executionListener = new ExecutionListener();
            Iterator commandItr = handleObjectsById.values().iterator();
            while (commandItr.hasNext()) {
                Command command = cast(Command) commandItr.next();
                command.addExecutionListener(executionListener);
            }

        }

        executionListeners.add(cast(Object)listener);
    }

    /*
     * (non-Javadoc)
     *
     * @see org.eclipse.core.commands.ICategoryListener#categoryChanged(org.eclipse.core.commands.CategoryEvent)
     */
    public final void categoryChanged(CategoryEvent categoryEvent) {
        if (categoryEvent.isDefinedChanged()) {
            Category category = categoryEvent.getCategory();
            String categoryId = category.getId();
            bool categoryIdAdded = category.isDefined();
            if (categoryIdAdded) {
                definedCategoryIds.add(categoryId);
            } else {
                definedCategoryIds.remove(categoryId);
            }
            if (isListenerAttached()) {
                fireCommandManagerChanged(new CommandManagerEvent(this, null,
                        false, false, categoryId, categoryIdAdded, true));
            }
        }
    }

    /*
     * (non-Javadoc)
     *
     * @see org.eclipse.commands.ICommandListener#commandChanged(org.eclipse.commands.CommandEvent)
     */
    public final void commandChanged(CommandEvent commandEvent) {
        if (commandEvent.isDefinedChanged()) {
            Command command = commandEvent.getCommand();
            String commandId = command.getId();
            bool commandIdAdded = command.isDefined();
            if (commandIdAdded) {
                definedHandleObjects.add(command);
            } else {
                definedHandleObjects.remove(command);
            }
            if (isListenerAttached()) {
                fireCommandManagerChanged(new CommandManagerEvent(this,
                        commandId, commandIdAdded, true, null, false, false));
            }
        }
    }

    /**
     * Sets the name and description of the category for uncategorized commands.
     * This is the category that will be returned if
     * {@link #getCategory(String)} is called with <code>null</code>.
     *
     * @param name
     *            The name of the category for uncategorized commands; must not
     *            be <code>null</code>.
     * @param description
     *            The description of the category for uncategorized commands;
     *            may be <code>null</code>.
     * @since 3.2
     */
    public final void defineUncategorizedCategory(String name,
            String description) {
        Category category = getCategory(AUTOGENERATED_CATEGORY_ID);
        category.define(name, description);
    }

    /**
     * <p>
     * Returns a {@link ParameterizedCommand} with a command and
     * parameterizations as specified in the provided
     * <code>serializedParameterizedCommand</code> string. The
     * <code>serializedParameterizedCommand</code> must use the format
     * returned by {@link ParameterizedCommand#serialize()} and described in the
     * Javadoc for that method.
     * </p>
     * <p>
     * If a parameter id encoded in the
     * <code>serializedParameterizedCommand</code> does not exist in the
     * encoded command, that parameter id and value are ignored. A given
     * parameter id should not be used more than once in
     * <code>serializedParameterizedCommand</code>. This will not result in
     * an exception, but in this case the value of the parameter when the
     * command is executed is unspecified.
     * </p>
     * <p>
     * This method will never return <code>null</code>, however it may throw
     * an exception if there is a problem processing the serialization string or
     * the encoded command is undefined.
     * </p>
     *
     * @param serializedParameterizedCommand
     *            a string representing a command id and parameter ids and
     *            values; must not be <code>null</code>
     * @return a {@link ParameterizedCommand} with the command and
     *         parameterizations encoded in the
     *         <code>serializedParameterizedCommand</code>; never
     *         <code>null</code>.
     * @throws NotDefinedException
     *             if the command indicated in
     *             <code>serializedParameterizedCommand</code> is not defined
     * @throws SerializationException
     *             if there is an error deserializing
     *             <code>serializedParameterizedCommand</code>
     * @see ParameterizedCommand#serialize()
     * @since 3.2
     */
    public final ParameterizedCommand deserialize(
            String serializedParameterizedCommand) {

        int lparenPosition = unescapedIndexOf(
                serializedParameterizedCommand, PARAMETER_START_CHAR);

        String commandIdEscaped;
        String serializedParameters;
        if (lparenPosition is -1) {
            commandIdEscaped = serializedParameterizedCommand;
            serializedParameters = null;
        } else {
            commandIdEscaped = serializedParameterizedCommand.substring(0,
                    lparenPosition);

            if (serializedParameterizedCommand
                    .charAt(serializedParameterizedCommand.length - 1) !is PARAMETER_END_CHAR) {
                throw new SerializationException(
                        "Parentheses must be balanced in serialized ParameterizedCommand"); //$NON-NLS-1$
            }

            serializedParameters = serializedParameterizedCommand.substring(
                    lparenPosition + 1, // skip PARAMETER_START_CHAR
                    serializedParameterizedCommand.length - 1); // skip
            // PARAMETER_END_CHAR
        }

        String commandId = unescape(commandIdEscaped);
        Command command = getCommand(commandId);
        IParameter[] parameters = command.getParameters();
        Parameterization[] parameterizations = getParameterizations(
                serializedParameters, parameters);

        return new ParameterizedCommand(command, parameterizations);
    }

    /**
     * Notifies all of the listeners to this manager that the set of defined
     * command identifiers has changed.
     *
     * @param event
     *            The event to send to all of the listeners; must not be
     *            <code>null</code>.
     */
    private final void fireCommandManagerChanged(CommandManagerEvent event) {
        if (event is null) {
            throw new NullPointerException();
        }

        Object[] listeners = getListeners();
        for (int i = 0; i < listeners.length; i++) {
            ICommandManagerListener listener = cast(ICommandManagerListener) listeners[i];
            listener.commandManagerChanged(event);
        }
    }

    /**
     * Returns all of the commands known by this manager -- defined and
     * undefined.
     *
     * @return All of the commands; may be empty, but never <code>null</code>.
     * @since 3.2
     */
    public final Command[] getAllCommands() {
        return arraycast!(Command)( handleObjectsById.values().toArray());
    }

    /**
     * Gets the category with the given identifier. If no such category
     * currently exists, then the category will be created (but be undefined).
     *
     * @param categoryId
     *            The identifier to find; must not be <code>null</code>. If
     *            the category is <code>null</code>, then a category suitable
     *            for uncategorized items is defined and returned.
     * @return The category with the given identifier; this value will never be
     *         <code>null</code>, but it might be undefined.
     * @see Category
     */
    public final Category getCategory(String categoryId) {
        if (categoryId is null) {
            return getCategory(AUTOGENERATED_CATEGORY_ID);
        }

        checkId(categoryId);

        Category category = cast(Category) categoriesById.get(categoryId);
        if (category is null) {
            category = new Category(categoryId);
            categoriesById.put(categoryId, category);
            category.addCategoryListener(this);
        }

        return category;
    }

    /**
     * Gets the command with the given identifier. If no such command currently
     * exists, then the command will be created (but will be undefined).
     *
     * @param commandId
     *            The identifier to find; must not be <code>null</code> and
     *            must not be zero-length.
     * @return The command with the given identifier; this value will never be
     *         <code>null</code>, but it might be undefined.
     * @see Command
     */
    public final Command getCommand(String commandId) {
        checkId(commandId);

        Command command = cast(Command) handleObjectsById.get(commandId);
        if (command is null) {
            command = new Command(commandId);
            handleObjectsById.put(commandId, command);
            command.addCommandListener(this);

            if (executionListener !is null) {
                command.addExecutionListener(executionListener);
            }
        }

        return command;
    }

    /**
     * Returns the categories that are defined.
     *
     * @return The defined categories; this value may be empty, but it is never
     *         <code>null</code>.
     * @since 3.2
     */
    public final Category[] getDefinedCategories() {
        Category[] categories = new Category[definedCategoryIds.size()];
        Iterator categoryIdItr = definedCategoryIds.iterator();
        int i = 0;
        while (categoryIdItr.hasNext()) {
            String categoryId = stringcast( categoryIdItr.next());
            categories[i++] = getCategory(categoryId);
        }
        return categories;
    }

    /**
     * Returns the set of identifiers for those category that are defined.
     *
     * @return The set of defined category identifiers; this value may be empty,
     *         but it is never <code>null</code>.
     */
    public final Set getDefinedCategoryIds() {
        return Collections.unmodifiableSet(definedCategoryIds);
    }

    /**
     * Returns the set of identifiers for those commands that are defined.
     *
     * @return The set of defined command identifiers; this value may be empty,
     *         but it is never <code>null</code>.
     */
    public final Set getDefinedCommandIds() {
        return getDefinedHandleObjectIds();
    }

    /**
     * Returns the commands that are defined.
     *
     * @return The defined commands; this value may be empty, but it is never
     *         <code>null</code>.
     * @since 3.2
     */
    public final Command[] getDefinedCommands() {
        return arraycast!(Command)( definedHandleObjects
                .toArray());
    }

    /**
     * Returns the set of identifiers for those parameter types that are
     * defined.
     *
     * @return The set of defined command parameter type identifiers; this value
     *         may be empty, but it is never <code>null</code>.
     * @since 3.2
     */
    public final Set getDefinedParameterTypeIds() {
        return Collections.unmodifiableSet(definedParameterTypeIds);
    }

    /**
     * Returns the command parameter types that are defined.
     *
     * @return The defined command parameter types; this value may be empty, but
     *         it is never <code>null</code>.
     * @since 3.2
     */
    public final ParameterType[] getDefinedParameterTypes() {
        ParameterType[] parameterTypes = new ParameterType[definedParameterTypeIds
                .size()];
        Iterator iterator = definedParameterTypeIds.iterator();
        int i = 0;
        while (iterator.hasNext()) {
            String parameterTypeId = stringcast( iterator.next());
            parameterTypes[i++] = getParameterType(parameterTypeId);
        }
        return parameterTypes;
    }

    /**
     * Gets the help context identifier for a particular command. The command's
     * handler is first checked for a help context identifier. If the handler
     * does not have a help context identifier, then the help context identifier
     * for the command is returned. If neither has a help context identifier,
     * then <code>null</code> is returned.
     *
     * @param command
     *            The command for which the help context should be retrieved;
     *            must not be <code>null</code>.
     * @return The help context identifier to use for the given command; may be
     *         <code>null</code>.
     * @throws NotDefinedException
     *             If the given command is not defined.
     * @since 3.2
     */
    public final String getHelpContextId(Command command) {
        // Check if the command is defined.
        if (!command.isDefined()) {
            throw new NotDefinedException("The command is not defined. " //$NON-NLS-1$
                    ~ command.getId());
        }

        // Check the handler.
        IHandler handler = command.getHandler();
        if (handler !is null) {
            String helpContextId = stringcast( helpContextIdsByHandler.get( cast(Object) handler) );
            if (helpContextId !is null) {
                return helpContextId;
            }
        }

        // Simply return whatever the command has as a help context identifier.
        return command.getHelpContextId();
    }

    /**
     * Returns an array of parameterizations for the provided command by
     * deriving the parameter ids and values from the provided
     * <code>serializedParameters</code> string.
     *
     * @param serializedParameters
     *            a String encoding parameter ids and values; must not be
     *            <code>null</code>.
     * @param parameters
     *            array of parameters of the command being deserialized; may be
     *            <code>null</code>.
     * @return an array of parameterizations; may be <code>null</code>.
     * @throws SerializationException
     *             if there is an error deserializing the parameters
     * @since 3.2
     */
    private final Parameterization[] getParameterizations(
            String serializedParameters, IParameter[] parameters) {

        if (serializedParameters is null
                || (serializedParameters.length is 0)) {
            return null;
        }

        if ((parameters is null) || (parameters.length is 0)) {
            return null;
        }

        ArrayList paramList = new ArrayList();

        int commaPosition; // split off each param by looking for ','
        do {
            commaPosition = unescapedIndexOf(serializedParameters, ',');

            String idEqualsValue;
            if (commaPosition is -1) {
                // no more parameters after this
                idEqualsValue = serializedParameters;
            } else {
                // take the first parameter...
                idEqualsValue = serializedParameters
                        .substring(0, commaPosition);

                // ... and put the rest back into serializedParameters
                serializedParameters = serializedParameters
                        .substring(commaPosition + 1);
            }

            int equalsPosition = unescapedIndexOf(idEqualsValue, '=');

            String parameterId;
            String parameterValue;
            if (equalsPosition is -1) {
                // missing values are null
                parameterId = unescape(idEqualsValue);
                parameterValue = null;
            } else {
                parameterId = unescape(idEqualsValue.substring(0,
                        equalsPosition));
                parameterValue = unescape(idEqualsValue
                        .substring(equalsPosition + 1));
            }

            for (int i = 0; i < parameters.length; i++) {
                IParameter parameter = parameters[i];
                if (parameter.getId().equals(parameterId)) {
                    paramList.add(new Parameterization(parameter,
                            parameterValue));
                    break;
                }
            }

        } while (commaPosition !is -1);

        return arraycast!(Parameterization)( paramList
                .toArray());
    }

    /**
     * Gets the command {@link ParameterType} with the given identifier. If no
     * such command parameter type currently exists, then the command parameter
     * type will be created (but will be undefined).
     *
     * @param parameterTypeId
     *            The identifier to find; must not be <code>null</code> and
     *            must not be zero-length.
     * @return The {@link ParameterType} with the given identifier; this value
     *         will never be <code>null</code>, but it might be undefined.
     * @since 3.2
     */
    public final ParameterType getParameterType(String parameterTypeId) {
        checkId(parameterTypeId);

        ParameterType parameterType = cast(ParameterType) parameterTypesById
                .get(parameterTypeId);
        if (parameterType is null) {
            parameterType = new ParameterType(parameterTypeId);
            parameterTypesById.put(parameterTypeId, parameterType);
            parameterType.addListener(this);
        }

        return parameterType;
    }

    /**
     * {@inheritDoc}
     *
     * @since 3.2
     */
    public final void parameterTypeChanged(
            ParameterTypeEvent parameterTypeEvent) {
        if (parameterTypeEvent.isDefinedChanged()) {
            ParameterType parameterType = parameterTypeEvent
                    .getParameterType();
            String parameterTypeId = parameterType.getId();
            bool parameterTypeIdAdded = parameterType.isDefined();
            if (parameterTypeIdAdded) {
                definedParameterTypeIds.add(parameterTypeId);
            } else {
                definedParameterTypeIds.remove(parameterTypeId);
            }

            fireCommandManagerChanged(new CommandManagerEvent(this,
                    parameterTypeId, parameterTypeIdAdded, true));
        }
    }

    /**
     * Removes a listener from this command manager.
     *
     * @param listener
     *            The listener to be removed; must not be <code>null</code>.
     */
    public final void removeCommandManagerListener(
            ICommandManagerListener listener) {
        removeListenerObject(cast(Object)listener);
    }

    /**
     * Removes an execution listener from this command manager.
     *
     * @param listener
     *            The listener to be removed; must not be <code>null</code>.
     */
    public final void removeExecutionListener(IExecutionListener listener) {
        if (listener is null) {
            throw new NullPointerException("Cannot remove a null listener"); //$NON-NLS-1$
        }

        if (executionListeners is null) {
            return;
        }

        executionListeners.remove(cast(Object)listener);

        if (executionListeners.isEmpty()) {
            executionListeners = null;

            // Remove the execution listener to every command.
            Iterator commandItr = handleObjectsById.values().iterator();
            while (commandItr.hasNext()) {
                Command command = cast(Command) commandItr.next();
                command.removeExecutionListener(executionListener);
            }
            executionListener = null;

        }
    }

    /**
     * Block updates all of the handlers for all of the commands. If the handler
     * is <code>null</code> or the command id does not exist in the map, then
     * the command becomes unhandled. Otherwise, the handler is set to the
     * corresponding value in the map.
     *
     * @param handlersByCommandId
     *            A map of command identifiers (<code>String</code>) to
     *            handlers (<code>IHandler</code>). This map may be
     *            <code>null</code> if all handlers should be cleared.
     *            Similarly, if the map is empty, then all commands will become
     *            unhandled.
     */
    public final void setHandlersByCommandId(Map handlersByCommandId) {
        // Make that all the reference commands are created.
        Iterator commandIdItr = handlersByCommandId.keySet().iterator();
        while (commandIdItr.hasNext()) {
            getCommand(stringcast(commandIdItr.next()));
        }

        // Now, set-up the handlers on all of the existing commands.
        Iterator commandItr = handleObjectsById.values().iterator();
        while (commandItr.hasNext()) {
            Command command = cast(Command) commandItr.next();
            String commandId = command.getId();
            Object value = handlersByCommandId.get(commandId);
            if ( cast(IHandler)value ) {
                command.setHandler(cast(IHandler) value);
            } else {
                command.setHandler(null);
            }
        }
    }

    /**
     * Sets the help context identifier to associate with a particular handler.
     *
     * @param handler
     *            The handler with which to register a help context identifier;
     *            must not be <code>null</code>.
     * @param helpContextId
     *            The help context identifier to register; may be
     *            <code>null</code> if the help context identifier should be
     *            removed.
     * @since 3.2
     */
    public final void setHelpContextId(IHandler handler,
            String helpContextId) {
        if (handler is null) {
            throw new NullPointerException("The handler cannot be null"); //$NON-NLS-1$
        }
        if (helpContextId is null) {
            helpContextIdsByHandler.remove(cast(Object) handler);
        } else {
            helpContextIdsByHandler.put(cast(Object) handler, stringcast(helpContextId));
        }
    }

    /**
     * Searches for the index of a <code>char</code> in a <code>String</code>
     * but disregards characters prefixed with the {@link #ESCAPE_CHAR} escape
     * character. This is used by {@link #deserialize(String)} and
     * {@link #getParameterizations(String, IParameter[])} to parse the
     * serialized parameterized command string.
     *
     * @param escapedText
     *            the string to search for the index of <code>ch</code> in
     * @param ch
     *            a character to search for in <code>escapedText</code>
     * @return the index of the first unescaped occurrence of the character in
     *         <code>escapedText</code>, or <code>-1</code> if the
     *         character does not occur unescaped.
     * @see String#indexOf(int)
     */
    private final int unescapedIndexOf(String escapedText, char ch) {

        int pos = escapedText.indexOf(ch);

        // first char can't be escaped
        if (pos is 0) {
            return pos;
        }

        while (pos !is -1) {
            // look back for the escape character
            if (escapedText.charAt(pos - 1) !is ESCAPE_CHAR) {
                return pos;
            }

            // scan for the next instance of ch
            pos = escapedText.indexOf(ch, pos + 1);
        }

        return pos;

    }
    /**
     * Fires the <code>notEnabled</code> event for
     * <code>executionListeners</code>.
     * <p>
     * <b>Note:</b> This supports bridging actions to the command framework,
     * and should not be used outside the framework.
     * </p>
     *
     * @param commandId
     *            The command id of the command about to execute, never
     *            <code>null</code>.
     * @param exception
     *            The exception, never <code>null</code>.
     * @since 3.4
     */
    public void fireNotEnabled(String commandId, NotEnabledException exception) {
        if (executionListener !is null) {
            executionListener.notEnabled(commandId, exception);
        }
    }

    /**
     * Fires the <code>notDefined</code> event for
     * <code>executionListeners</code>.
     * <p>
     * <b>Note:</b> This supports bridging actions to the command framework,
     * and should not be used outside the framework.
     * </p>
     *
     * @param commandId
     *            The command id of the command about to execute, never
     *            <code>null</code>.
     * @param exception
     *            The exception, never <code>null</code>.
     * @since 3.4
     */
    public void fireNotDefined(String commandId, NotDefinedException exception) {
        if (executionListener !is null) {
            executionListener.notDefined(commandId, exception);
        }
    }

    /**
     * Fires the <code>preExecute</code> event for
     * <code>executionListeners</code>.
     * <p>
     * <b>Note:</b> This supports bridging actions to the command framework,
     * and should not be used outside the framework.
     * </p>
     *
     * @param commandId
     *            The command id of the command about to execute, never
     *            <code>null</code>.
     * @param event
     *            The event that triggered the command, may be <code>null</code>.
     * @since 3.4
     */
    public void firePreExecute(String commandId, ExecutionEvent event) {
        if (executionListener !is null) {
            executionListener.preExecute(commandId, event);
        }
    }

    /**
     * Fires the <code>postExecuteSuccess</code> event for
     * <code>executionListeners</code>.
     * <p>
     * <b>Note:</b> This supports bridging actions to the command framework,
     * and should not be used outside the framework.
     * </p>
     *
     * @param commandId
     *            The command id of the command executed, never
     *            <code>null</code>.
     * @param returnValue
     *            The value returned from the command, may be <code>null</code>.
     * @since 3.4
     */
    public void firePostExecuteSuccess(String commandId, Object returnValue) {
        if (executionListener !is null) {
            executionListener.postExecuteSuccess(commandId, returnValue);
        }
    }

    /**
     * Fires the <code>postExecuteFailure</code> event for
     * <code>executionListeners</code>.
     * <p>
     * <b>Note:</b> This supports bridging actions to the command framework,
     * and should not be used outside the framework.
     * </p>
     *
     * @param commandId
     *            The command id of the command executed, never
     *            <code>null</code>.
     * @param exception
     *            The exception, never <code>null</code>.
     * @since 3.4
     */
    public void firePostExecuteFailure(String commandId,
            ExecutionException exception) {
        if (executionListener !is null) {
            executionListener.postExecuteFailure(commandId, exception);
        }
    }
}
