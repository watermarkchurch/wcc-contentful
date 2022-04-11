FROM watermarkchurch/workspace-full
USER gitpod

RUN sudo apt-get install -y postgresql-client-12

# https://www.gitpod.io/docs/languages/ruby
RUN _ruby_version=ruby-2.5.7 \
    && printf "rvm_gems_path=/home/gitpod/.rvm\n" > ~/.rvmrc \
    && bash -lc "rvm reinstall ruby-${_ruby_version} && rvm use ruby-${_ruby_version} --default" \
    && printf "rvm_gems_path=/workspace/.rvm" > ~/.rvmrc \
    && printf '{ rvm use $(rvm current); } >/dev/null 2>&1\n' >> "$HOME/.bashrc.d/70-ruby"

# https://www.gitpod.io/docs/languages/javascript#node-versions
RUN bash -c 'VERSION="17" && source $HOME/.nvm/nvm.sh && nvm install $VERSION && nvm use $VERSION && nvm alias default $VERSION && npm install --global yarn'
RUN echo "nvm use default &>/dev/null" >> ~/.bashrc.d/51-nvm-fix
