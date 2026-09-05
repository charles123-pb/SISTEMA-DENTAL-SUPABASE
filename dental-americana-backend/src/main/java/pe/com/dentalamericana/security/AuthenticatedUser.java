package pe.com.dentalamericana.security;

import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import pe.com.dentalamericana.user.AppUser;

import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.Set;

public class AuthenticatedUser implements UserDetails {
    private final Long id;
    private final String username;
    private final String password;
    private final String fullName;
    private final boolean active;
    private final boolean locked;
    private final Set<GrantedAuthority> authorities;

    private AuthenticatedUser(Long id, String username, String password, String fullName,
                              boolean active, boolean locked, Set<GrantedAuthority> authorities) {
        this.id = id;
        this.username = username;
        this.password = password;
        this.fullName = fullName;
        this.active = active;
        this.locked = locked;
        this.authorities = Set.copyOf(authorities);
    }

    public static AuthenticatedUser from(AppUser user) {
        Set<GrantedAuthority> authorities = new LinkedHashSet<>();
        user.getRoles().forEach(role -> {
            authorities.add(new SimpleGrantedAuthority("ROLE_" + role.getCode().name()));
            role.getPermissions().forEach(permission ->
                    authorities.add(new SimpleGrantedAuthority(permission.getCode().name())));
        });
        return new AuthenticatedUser(user.getId(), user.getUsername(), user.getPasswordHash(),
                user.getFullName(), user.isActive(), user.isLocked(), authorities);
    }

    public Long getId() { return id; }
    public String getFullName() { return fullName; }
    @Override public String getUsername() { return username; }
    @Override public String getPassword() { return password; }
    @Override public Collection<? extends GrantedAuthority> getAuthorities() { return authorities; }
    @Override public boolean isAccountNonExpired() { return true; }
    @Override public boolean isAccountNonLocked() { return !locked; }
    @Override public boolean isCredentialsNonExpired() { return true; }
    @Override public boolean isEnabled() { return active; }
}
