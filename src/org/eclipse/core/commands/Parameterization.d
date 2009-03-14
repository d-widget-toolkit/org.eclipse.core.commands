/*******************************************************************************
 * Copyright (c) 2005 IBM Corporation and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * Contributors:
 *     IBM Corporation - initial API and implementation
 * Port to the D programming language:
 *     Frank Benoit <benoit@tionex.de>
 ******************************************************************************/

module org.eclipse.core.commands.Parameterization;

import org.eclipse.core.commands.IParameter;
import org.eclipse.core.internal.commands.util.Util;

import java.lang.all;
import java.util.Map;
import java.util.Iterator;

/**
 * <p>
 * A parameter with a specific value. This is usually a part of a
 * <code>ParameterizedCommand</code>, which is used to refer to a command
 * with a collection of parameterizations.
 * </p>
 *
 * @since 3.1
 */
public final class Parameterization {

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
        HASH_INITIAL = java.lang.all.toHash( Parameterization.classinfo.name );
    }
    /**
     * The hash code for this object. This value is computed lazily, and marked
     * as invalid when one of the values on which it is based changes.
     */
    private /+transient+/ hash_t hashCode = HASH_CODE_NOT_COMPUTED;

    /**
     * The parameter that is being parameterized. This value is never
     * <code>null</code>.
     */
    private const IParameter parameter;

    /**
     * The value that defines the parameterization. This value may be
     * <code>null</code>.
     */
    private const String value;

    /**
     * Constructs a new instance of <code>Parameterization</code>.
     *
     * @param parameter
     *            The parameter that is being parameterized; must not be
     *            <code>null</code>.
     * @param value
     *            The value for the parameter; may be <code>null</code>.
     */
    public this(IParameter parameter, String value) {
        if (parameter is null) {
            throw new NullPointerException(
                    "You cannot parameterize a null parameter"); //$NON-NLS-1$
        }

        this.parameter = parameter;
        this.value = value;
    }

    /* (non-Javadoc)
     * @see java.lang.Object#equals(java.lang.Object)
     */
    public override final int opEquals(Object object) {
        if (this is object) {
            return true;
        }

        if (!(cast(Parameterization)object)) {
            return false;
        }

        Parameterization parameterization = cast(Parameterization) object;
        if (!(Util.equals(this.parameter.getId(), parameterization.parameter
                .getId()))) {
            return false;
        }

        return Util.equals(this.value, parameterization.value);
    }

    /**
     * Returns the parameter that is being parameterized.
     *
     * @return The parameter; never <code>null</code>.
     */
    public final IParameter getParameter() {
        return parameter;
    }

    /**
     * Returns the value for the parameter in this parameterization.
     *
     * @return The value; may be <code>null</code>.
     */
    public final String getValue() {
        return value;
    }

    /**
     * Returns the human-readable name for the current value, if any. If the
     * name cannot be found, then it simply returns the value. It also ensures
     * that any <code>null</code> values are converted into an empty string.
     *
     * @return The human-readable name of the value; never <code>null</code>.
     * @throws ParameterValuesException
     *             If the parameter needed to be initialized, but couldn't be.
     */
    public final String getValueName() {
        Map parameterValues = parameter.getValues().getParameterValues();
        Iterator parameterValueItr = parameterValues.entrySet()
                .iterator();
        String returnValue = null;
        while (parameterValueItr.hasNext()) {
            Map.Entry entry = cast(Map.Entry) parameterValueItr.next();
            String currentValue = stringcast( entry.getValue());
            if (Util.equals(value, currentValue)) {
                returnValue = stringcast( entry.getKey());
                break;
            }
        }

        if (returnValue is null) {
            return Util.ZERO_LENGTH_STRING;
        }

        return returnValue;
    }

    /* (non-Javadoc)
     * @see java.lang.Object#hashCode()
     */
    public override final hash_t toHash() {
        if (hashCode is HASH_CODE_NOT_COMPUTED) {
            hashCode = HASH_INITIAL * HASH_FACTOR + Util.toHash(cast(Object)parameter);
            hashCode = hashCode * HASH_FACTOR + Util.toHash(value);
            if (hashCode is HASH_CODE_NOT_COMPUTED) {
                hashCode++;
            }
        }
        return hashCode;
    }
}
