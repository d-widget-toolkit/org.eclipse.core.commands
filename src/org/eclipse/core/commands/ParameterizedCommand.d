/*******************************************************************************
 * Copyright (c) 2005, 2008 IBM Corporation and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * Contributors:
 *     IBM Corporation - initial API and implementation
 *     Benjamin Muskalla - bug 222861 [Commands] ParameterizedCommand#equals broken
 * Port to the D programming language:
 *     Frank Benoit <benoit@tionex.de>
 *******************************************************************************/

module org.eclipse.core.commands.ParameterizedCommand;

import org.eclipse.core.commands.AbstractParameterValueConverter;
import org.eclipse.core.commands.Command;
import org.eclipse.core.commands.CommandManager;
import org.eclipse.core.commands.IParameter;
import org.eclipse.core.commands.IParameterValues;
import org.eclipse.core.commands.ParameterType;
import org.eclipse.core.commands.Parameterization;
import org.eclipse.core.commands.ParameterValuesException;
import org.eclipse.core.commands.ParameterValueConversionException;
import org.eclipse.core.commands.ExecutionEvent;
import org.eclipse.core.commands.common.NotDefinedException;
import org.eclipse.core.internal.commands.util.Util;

import java.lang.all;
import java.util.Map;
import java.util.HashMap;
import java.util.List;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.Collection;
import java.util.Collections;

/**
 * <p>
 * A command that has had one or more of its parameters specified. This class
 * serves as a utility class for developers that need to manipulate commands
 * with parameters. It handles the behaviour of generating a parameter map and a
 * human-readable name.
 * </p>
 *
 * @since 3.1
 */
public final class ParameterizedCommand : Comparable {
    /**
     * The constant integer hash code value meaning the hash code has not yet
     * been computed.
     */
    private static const int HASH_CODE_NOT_COMPUTED = -1;

    /**
     * A factor for computing the hash code for all parameterized commands.
     */
    private static const int HASH_FACTOR = 89;

    /**
     * The seed for the hash code for all parameterized commands.
     */
    private static const int HASH_INITIAL;

    static this(){
        HASH_INITIAL = java.lang.all.toHash(ParameterizedCommand.classinfo.name );
    }
    /**
     * The index of the parameter id in the parameter values.
     *
     * @deprecated no longer used
     */
    public static const int INDEX_PARAMETER_ID = 0;

    /**
     * The index of the human-readable name of the parameter itself, in the
     * parameter values.
     *
     * @deprecated no longer used
     */
    public static const int INDEX_PARAMETER_NAME = 1;

    /**
     * The index of the human-readable name of the value of the parameter for
     * this command.
     *
     * @deprecated no longer used
     */
    public static const int INDEX_PARAMETER_VALUE_NAME = 2;

    /**
     * The index of the value of the parameter that the command can understand.
     *
     * @deprecated no longer used
     */
    public static const int INDEX_PARAMETER_VALUE_VALUE = 3;

    /**
     * Escapes special characters in the command id, parameter ids and parameter
     * values for {@link #serialize()}. The special characters
     * {@link CommandManager#PARAMETER_START_CHAR},
     * {@link CommandManager#PARAMETER_END_CHAR},
     * {@link CommandManager#ID_VALUE_CHAR},
     * {@link CommandManager#PARAMETER_SEPARATOR_CHAR} and
     * {@link CommandManager#ESCAPE_CHAR} are escaped by prepending a
     * {@link CommandManager#ESCAPE_CHAR} character.
     *
     * @param rawText
     *            a <code>String</code> to escape special characters in for
     *            serialization.
     * @return a <code>String</code> representing <code>rawText</code> with
     *         special serialization characters escaped
     * @since 3.2
     */
    private static final String escape(String rawText) {

        // defer initialization of a StringBuffer until we know we need one
        StringBuffer buffer;

        for (int i = 0; i < rawText.length; i++) {

            char c = rawText.charAt(i);
            switch (c) {
            case CommandManager.PARAMETER_START_CHAR:
            case CommandManager.PARAMETER_END_CHAR:
            case CommandManager.ID_VALUE_CHAR:
            case CommandManager.PARAMETER_SEPARATOR_CHAR:
            case CommandManager.ESCAPE_CHAR:
                if (buffer is null) {
                    buffer = new StringBuffer(rawText.substring(0, i));
                }
                buffer.append(CommandManager.ESCAPE_CHAR);
                buffer.append(c);
                break;
            default:
                if (buffer !is null) {
                    buffer.append(c);
                }
                break;
            }

        }

        if (buffer is null) {
            return rawText;
        }
        return buffer.toString();
    }

    /**
     * Generates every possible combination of parameter values for the given
     * parameters. Parameters values that cannot be initialized are just
     * ignored. Optional parameters are considered.
     *
     * @param startIndex
     *            The index in the <code>parameters</code> that we should
     *            process. This must be a valid index.
     * @param parameters
     *            The parameters in to process; must not be <code>null</code>.
     * @return A collection (<code>Collection</code>) of combinations (<code>List</code>
     *         of <code>Parameterization</code>).
     */
    private static final Collection expandParameters(int startIndex,
            IParameter[] parameters) {
        int nextIndex = startIndex + 1;
        bool noMoreParameters = (nextIndex >= parameters.length);

        IParameter parameter = parameters[startIndex];
        List parameterizations = new ArrayList();
        if (parameter.isOptional()) {
            parameterizations.add( cast(Object) null);
        }

        IParameterValues values = null;
        try {
            values = parameter.getValues();
        } catch (ParameterValuesException e) {
            if (noMoreParameters) {
                return parameterizations;
            }

            // Make recursive call
            return expandParameters(nextIndex, parameters);
        }

        Map parameterValues = values.getParameterValues();
        Iterator parameterValueItr = parameterValues.entrySet()
                .iterator();
        while (parameterValueItr.hasNext()) {
            Map.Entry entry = cast(Map.Entry) parameterValueItr.next();
            Parameterization parameterization = new Parameterization(
                    parameter, stringcast( entry.getValue()));
            parameterizations.add(parameterization);
        }

        // Check if another iteration will produce any more names.
        int parameterizationCount = parameterizations.size();
        if (noMoreParameters) {
            // This is it, so just return the current parameterizations.
            for (int i = 0; i < parameterizationCount; i++) {
                Parameterization parameterization = cast(Parameterization) parameterizations
                        .get(i);
                List combination = new ArrayList();
                combination.add(parameterization);
                parameterizations.set(i, cast(Object)combination);
            }
            return parameterizations;
        }

        // Make recursive call
        Collection suffixes = expandParameters(nextIndex, parameters);
        while (suffixes.remove(cast(Object)null)) {
            // just keep deleting the darn things.
        }
        if (suffixes.isEmpty()) {
            // This is it, so just return the current parameterizations.
            for (int i = 0; i < parameterizationCount; i++) {
                Parameterization parameterization = cast(Parameterization) parameterizations
                        .get(i);
                List combination = new ArrayList();
                combination.add(parameterization);
                parameterizations.set(i,cast(Object) combination);
            }
            return parameterizations;
        }
        Collection returnValue = new ArrayList();
        Iterator suffixItr = suffixes.iterator();
        while (suffixItr.hasNext()) {
            List combination = cast(List) suffixItr.next();
            int combinationSize = combination.size();
            for (int i = 0; i < parameterizationCount; i++) {
                Parameterization parameterization = cast(Parameterization) parameterizations
                        .get(i);
                List newCombination = new ArrayList(combinationSize + 1);
                newCombination.add(parameterization);
                newCombination.addAll(combination);
                returnValue.add(cast(Object)newCombination);
            }
        }

        return returnValue;
    }

    /**
     * <p>
     * Generates all the possible combinations of command parameterizations for
     * the given command. If the command has no parameters, then this is simply
     * a parameterized version of that command. If a parameter is optional, both
     * the included and not included cases are considered.
     * </p>
     * <p>
     * If one of the parameters cannot be loaded due to a
     * <code>ParameterValuesException</code>, then it is simply ignored.
     * </p>
     *
     * @param command
     *            The command for which the parameter combinations should be
     *            generated; must not be <code>null</code>.
     * @return A collection of <code>ParameterizedCommand</code> instances
     *         representing all of the possible combinations. This value is
     *         never empty and it is never <code>null</code>.
     * @throws NotDefinedException
     *             If the command is not defined.
     */
    public static final Collection generateCombinations(Command command) {
        IParameter[] parameters = command.getParameters();
        if (parameters is null) {
            return Collections
                    .singleton(new ParameterizedCommand(command, null));
        }

        Collection expansion = expandParameters(0, parameters);
        Collection combinations = new ArrayList(expansion.size());
        Iterator expansionItr = expansion.iterator();
        while (expansionItr.hasNext()) {
            List combination = cast(List) expansionItr.next();
            if (combination is null) {
                combinations.add(new ParameterizedCommand(command, null));
            } else {
                while (combination.remove(cast(Object)null)) {
                    // Just keep removing while there are null entries left.
                }
                if (combination.isEmpty()) {
                    combinations.add(new ParameterizedCommand(command, null));
                } else {
                    Parameterization[] parameterizations = arraycast!(Parameterization)( combination
                            .toArray());
                    combinations.add(new ParameterizedCommand(command,
                            parameterizations));
                }
            }
        }

        return combinations;
    }

    /**
     * Take a command and a map of parameter IDs to values, and generate the
     * appropriate parameterized command.
     *
     * @param command
     *            The command object. Must not be <code>null</code>.
     * @param parameters
     *            A map of String parameter ids to objects. May be
     *            <code>null</code>.
     * @return the parameterized command, or <code>null</code> if it could not
     *         be generated
     * @since 3.4
     */
    public static final ParameterizedCommand generateCommand(Command command,
            Map parameters) {
        // no parameters
        if (parameters is null || parameters.isEmpty()) {
            return new ParameterizedCommand(command, null);
        }

        try {
            ArrayList parms = new ArrayList();
            Iterator i = parameters.keySet().iterator();

            // iterate over given parameters
            while (i.hasNext()) {
                String key = stringcast( i.next() );
                IParameter parameter = null;
                // get the parameter from the command
                parameter = command.getParameter(key);

                // if the parameter is defined add it to the parameter list
                if (parameter is null) {
                    return null;
                }
                ParameterType parameterType = command.getParameterType(key);
                if (parameterType is null) {
                    parms.add(new Parameterization(parameter,
                            stringcast( parameters.get(key))));
                } else {
                    AbstractParameterValueConverter valueConverter = parameterType
                            .getValueConverter();
                    if (valueConverter !is null) {
                        String val = valueConverter.convertToString( parameters
                                .get(key));
                        parms.add(new Parameterization(parameter, val));
                    } else {
                        parms.add(new Parameterization(parameter,
                                stringcast(parameters.get(key))));
                    }
                }
            }

            // convert the parameters to an Parameterization array and create
            // the command
            return new ParameterizedCommand(command, arraycast!(Parameterization)( parms
                    .toArray()));
        } catch (NotDefinedException e) {
        } catch (ParameterValueConversionException e) {
        }
        return null;
    }

    /**
     * The base command which is being parameterized. This value is never
     * <code>null</code>.
     */
    private const Command command;

    /**
     * The hash code for this object. This value is computed lazily, and marked
     * as invalid when one of the values on which it is based changes.
     */
    private /+transient+/ int hashCode = HASH_CODE_NOT_COMPUTED;

    /**
     * This is an array of parameterization defined for this command. This value
     * may be <code>null</code> if the command has no parameters.
     */
    private const Parameterization[] parameterizations;

    private String name;

    /**
     * Constructs a new instance of <code>ParameterizedCommand</code> with
     * specific values for zero or more of its parameters.
     *
     * @param command
     *            The command that is parameterized; must not be
     *            <code>null</code>.
     * @param parameterizations
     *            An array of parameterizations binding parameters to values for
     *            the command. This value may be <code>null</code>.
     */
    public this(Command command,
            Parameterization[] parameterizations) {
        if (command is null) {
            throw new NullPointerException(
                    "A parameterized command cannot have a null command"); //$NON-NLS-1$
        }

        this.command = command;
        IParameter[] parms = null;
        try {
            parms = command.getParameters();
        } catch (NotDefinedException e) {
            // This should not happen.
        }
        if (parameterizations !is null && parameterizations.length>0 && parms !is null) {
            int parmIndex = 0;
            Parameterization[] params = new Parameterization[parameterizations.length];
            for (int j = 0; j < parms.length; j++) {
                for (int i = 0; i < parameterizations.length; i++) {
                    Parameterization pm = parameterizations[i];
                    if ((cast(Object)parms[j]).opEquals(cast(Object)pm.getParameter())) {
                        params[parmIndex++] = pm;
                    }
                }
            }
            this.parameterizations = params;
        } else {
            this.parameterizations = null;
        }
    }

    /*
     * (non-Javadoc)
     *
     * @see java.lang.Comparable#compareTo(java.lang.Object)
     */
    public final int compareTo(Object object) {
        ParameterizedCommand command = cast(ParameterizedCommand) object;
        bool thisDefined = this.command.isDefined();
        bool otherDefined = command.command.isDefined();
        if (!thisDefined || !otherDefined) {
            return Util.compare(thisDefined, otherDefined);
        }

        try {
            int compareTo = getName() < command.getName();
            if (compareTo is 0) {
                return getId() < command.getId();
            }
            return compareTo;
        } catch (NotDefinedException e) {
            throw new Exception (
                    "Concurrent modification of a command's defined state"); //$NON-NLS-1$
        }
    }
    public final override int opCmp( Object object ){
        return compareTo( object );
    }

    /*
     * (non-Javadoc)
     *
     * @see java.lang.Object#equals(java.lang.Object)
     */
    public override final int opEquals(Object object) {
        if (this is object) {
            return true;
        }

        if (!(cast(ParameterizedCommand)object)) {
            return false;
        }

        ParameterizedCommand command = cast(ParameterizedCommand) object;
        if (!Util.equals(this.command, command.command)) {
            return false;
        }

        return Util.equals(this.parameterizations, command.parameterizations);
    }

    /**
     * Executes this command with its parameters. This method will succeed
     * regardless of whether the command is enabled or defined. It is
     * preferrable to use {@link #executeWithChecks(Object, Object)}.
     *
     * @param trigger
     *            The object that triggered the execution; may be
     *            <code>null</code>.
     * @param applicationContext
     *            The state of the application at the time the execution was
     *            triggered; may be <code>null</code>.
     * @return The result of the execution; may be <code>null</code>.
     * @throws ExecutionException
     *             If the handler has problems executing this command.
     * @throws NotHandledException
     *             If there is no handler.
     * @deprecated Please use {@link #executeWithChecks(Object, Object)}
     *             instead.
     */
    public final Object execute(Object trigger,
            Object applicationContext) {
        return command.execute(new ExecutionEvent(command, getParameterMap(),
                trigger, applicationContext));
    }

    /**
     * Executes this command with its parameters. This does extra checking to
     * see if the command is enabled and defined. If it is not both enabled and
     * defined, then the execution listeners will be notified and an exception
     * thrown.
     *
     * @param trigger
     *            The object that triggered the execution; may be
     *            <code>null</code>.
     * @param applicationContext
     *            The state of the application at the time the execution was
     *            triggered; may be <code>null</code>.
     * @return The result of the execution; may be <code>null</code>.
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
    public final Object executeWithChecks(Object trigger,
            Object applicationContext) {
        return command.executeWithChecks(new ExecutionEvent(command,
                getParameterMap(), trigger, applicationContext));
    }

    /**
     * Returns the base command. It is possible for more than one parameterized
     * command to have the same identifier.
     *
     * @return The command; never <code>null</code>, but may be undefined.
     */
    public final Command getCommand() {
        return command;
    }

    /**
     * Returns the command's base identifier. It is possible for more than one
     * parameterized command to have the same identifier.
     *
     * @return The command id; never <code>null</code>.
     */
    public final String getId() {
        return command.getId();
    }

    /**
     * Returns a human-readable representation of this command with all of its
     * parameterizations.
     *
     * @return The human-readable representation of this parameterized command;
     *         never <code>null</code>.
     * @throws NotDefinedException
     *             If the underlying command is not defined.
     */
    public final String getName() {
        if (name is null) {
            StringBuffer nameBuffer = new StringBuffer();
            nameBuffer.append(command.getName());
            if (parameterizations !is null) {
                nameBuffer.append(" ("); //$NON-NLS-1$
                int parameterizationCount = parameterizations.length;
                for (int i = 0; i < parameterizationCount; i++) {
                    Parameterization parameterization = parameterizations[i];
                    nameBuffer
                            .append(parameterization.getParameter().getName());
                    nameBuffer.append(": "); //$NON-NLS-1$
                    try {
                        nameBuffer.append(parameterization.getValueName());
                    } catch (ParameterValuesException e) {
                        /*
                         * Just let it go for now. If someone complains we can
                         * add more info later.
                         */
                    }

                    // If there is another item, append a separator.
                    if (i + 1 < parameterizationCount) {
                        nameBuffer.append(", "); //$NON-NLS-1$
                    }
                }
                nameBuffer.append(')');
            }
            name = nameBuffer.toString();
        }
        return name;
    }

    /**
     * Returns the parameter map, as can be used to construct an
     * <code>ExecutionEvent</code>.
     *
     * @return The map of parameter ids (<code>String</code>) to parameter
     *         values (<code>String</code>). This map is never
     *         <code>null</code>, but may be empty.
     */
    public final Map getParameterMap() {
        if ((parameterizations is null) || (parameterizations.length is 0)) {
            return Collections.EMPTY_MAP;
        }

        Map parameterMap = new HashMap();
        for (int i = 0; i < parameterizations.length; i++) {
            Parameterization parameterization = parameterizations[i];
            parameterMap.put(parameterization.getParameter().getId(),
                    parameterization.getValue());
        }
        return parameterMap;
    }

    /*
     * (non-Javadoc)
     *
     * @see java.lang.Object#hashCode()
     */
    public override final hash_t toHash() {
        if (hashCode is HASH_CODE_NOT_COMPUTED) {
            hashCode = HASH_INITIAL * HASH_FACTOR + Util.toHash(command);
            hashCode = hashCode * HASH_FACTOR;
            if (parameterizations !is null) {
                for (int i = 0; i < parameterizations.length; i++) {
                    hashCode += Util.toHash(parameterizations[i]);
                }
            }
            if (hashCode is HASH_CODE_NOT_COMPUTED) {
                hashCode++;
            }
        }
        return hashCode;
    }

    /**
     * Returns a {@link String} containing the command id, parameter ids and
     * parameter values for this {@link ParameterizedCommand}. The returned
     * {@link String} can be stored by a client and later used to reconstruct an
     * equivalent {@link ParameterizedCommand} using the
     * {@link CommandManager#deserialize(String)} method.
     * <p>
     * The syntax of the returned {@link String} is as follows:
     * </p>
     *
     * <blockquote>
     * <code>serialization = <u>commandId</u> [ '(' parameters ')' ]</code><br>
     * <code>parameters = parameter [ ',' parameters ]</code><br>
     * <code>parameter = <u>parameterId</u> [ '=' <u>parameterValue</u> ]</code>
     * </blockquote>
     *
     * <p>
     * In the syntax above, sections inside square-brackets are optional. The
     * characters in single quotes (<code>(</code>, <code>)</code>,
     * <code>,</code> and <code>=</code>) indicate literal characters.
     * </p>
     * <p>
     * <code><u>commandId</u></code> represents the command id encoded with
     * separator characters escaped. <code><u>parameterId</u></code> and
     * <code><u>parameterValue</u></code> represent the parameter ids and
     * values encoded with separator characters escaped. The separator
     * characters <code>(</code>, <code>)</code>, <code>,</code> and
     * <code>=</code> are escaped by prepending a <code>%</code>. This
     * requires <code>%</code> to be escaped, which is also done by prepending
     * a <code>%</code>.
     * </p>
     * <p>
     * The order of the parameters is not defined (and not important). A missing
     * <code><u>parameterValue</u></code> indicates that the value of the
     * parameter is <code>null</code>.
     * </p>
     * <p>
     * For example, the string shown below represents a serialized parameterized
     * command that can be used to show the Resource perspective:
     * </p>
     * <p>
     * <code>org.eclipse.ui.perspectives.showPerspective(org.eclipse.ui.perspectives.showPerspective.perspectiveId=org.eclipse.ui.resourcePerspective)</code>
     * </p>
     * <p>
     * This example shows the more general form with multiple parameters,
     * <code>null</code> value parameters, and escaped <code>=</code> in the
     * third parameter value.
     * </p>
     * <p>
     * <code>command.id(param1.id=value1,param2.id,param3.id=esc%=val3)</code>
     * </p>
     *
     * @return A string containing the escaped command id, parameter ids and
     *         parameter values; never <code>null</code>.
     * @see CommandManager#deserialize(String)
     * @since 3.2
     */
    public final String serialize() {
        String escapedId = escape(getId());

        if ((parameterizations is null) || (parameterizations.length is 0)) {
            return escapedId;
        }

        StringBuffer buffer = new StringBuffer(escapedId);
        buffer.append(CommandManager.PARAMETER_START_CHAR);

        for (int i = 0; i < parameterizations.length; i++) {

            if (i > 0) {
                // insert separator between parameters
                buffer.append(CommandManager.PARAMETER_SEPARATOR_CHAR);
            }

            Parameterization parameterization = parameterizations[i];
            String parameterId = parameterization.getParameter().getId();
            String escapedParameterId = escape(parameterId);

            buffer.append(escapedParameterId);

            String parameterValue = parameterization.getValue();
            if (parameterValue !is null) {
                String escapedParameterValue = escape(parameterValue);
                buffer.append(CommandManager.ID_VALUE_CHAR);
                buffer.append(escapedParameterValue);
            }
        }

        buffer.append(CommandManager.PARAMETER_END_CHAR);

        return buffer.toString();
    }

    public override final String toString() {
        return Format( "ParameterizedCommand({},{})", command, parameterizations);
    }
}
