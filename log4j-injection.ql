/**
 * @name Log4j Injection
 * @description Detects log4j calls with user-controlled data.
 * @kind path-problem
 * @problem.severity error
 * @precision high
 * @id java/log-injection
 * @tags security
 *       external/cwe/cwe-117
 */

import java
import DataFlow::PathGraph
import semmle.code.java.dataflow.FlowSources

class Log4jCall extends MethodAccess {
  Log4jCall() {
    exists(RefType t, Method m |
      t.hasQualifiedName("org.apache.log4j", ["Category", "Logger", "LogBuilder"]) or // Log4j v1
      t.hasQualifiedName("org.apache.logging.log4j", ["Logger", "LogBuilder", "LoggerManager"]) or // Log4j v2 or
      t.hasQualifiedName("org.apache.logging.log4j.core", ["Logger", "LogBuilder", "LoggerManager"]) or // Log4j v2 
      t.hasQualifiedName("org.apache.logging.log4j.status", "StatusLogger") // Log4j Status logger
      |
      (
        m.getDeclaringType().getASourceSupertype*() = t or
        m.getDeclaringType().extendsOrImplements*(t)
      ) and
      m.getReturnType() instanceof VoidType and
      this = m.getAReference()
    )
  }

  Argument getALogArgument() { result = this.getArgument(_) }
}

/**
 * A taint-tracking configuration for tracking untrusted user input used in log entries.
 */
private class Log4JInjectionConfiguration extends TaintTracking::Configuration {
  Log4JInjectionConfiguration() { this = "Log4j Injection" }

  override predicate isSource(DataFlow::Node source) { source instanceof RemoteFlowSource }

  override predicate isSink(DataFlow::Node sink) {
    sink.asExpr() = any(Log4jCall c).getALogArgument()
  }

  override predicate isSanitizer(DataFlow::Node node) {
    node.getType() instanceof BoxedType or node.getType() instanceof PrimitiveType
  }
}

from Log4JInjectionConfiguration cfg, DataFlow::PathNode source, DataFlow::PathNode sink
where cfg.hasFlowPath(source, sink)
select sink.getNode(), source, sink, "$@ flows to log4j call.", source.getNode(),
  "User-provided value"
