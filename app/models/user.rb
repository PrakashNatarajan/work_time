class User < Principal

  def allowed_to?(action, context, options={}, &block)
    #context = context.to_a.uniq if context and context.class.name == "ActiveRecord::Relation"
    if context && context.is_a?(Project)
      return false unless context.allows_to?(action)
      # Admin users are authorized for anything else
      return true if admin?

      roles = roles_for_project(context)
      return false unless roles
      roles.any? {|role|
        (context.is_public? || role.member?) &&
        role.allowed_to?(action) &&
        (block_given? ? yield(role, self) : true)
      }
    elsif context && (context.is_a?(Array) || context.is_a?(ActiveRecord::Relation))
      if context.empty?
        false
      else
        # Authorize if user is authorized on every element of the array
        context.map {|project| allowed_to?(action, project, options, &block)}.reduce(:&)
      end
    elsif options[:global]
      # Admin users are always authorized
      return true if admin?

      # authorize if user has at least one role that has this permission
      roles = memberships.collect {|m| m.roles}.flatten.uniq
      roles << (self.logged? ? Role.non_member : Role.anonymous)
      roles.any? {|role|
        role.allowed_to?(action) &&
        (block_given? ? yield(role, self) : true)
      }
    else
      false
    end
  end

end
